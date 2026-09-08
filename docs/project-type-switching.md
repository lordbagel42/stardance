# Project type switching (hardware ↔ software) — plan

Admins need to flip a project between hardware and software after the point
where the builder can no longer do it themselves: once a funding request or a
ship exists. The canonical example is a design-funding request that a reviewer
returned with "this should have been submitted as a software project". Today
there is no way to act on that verdict short of a console session.

This document inventories everything that hangs off the hardware/software
distinction, walks every state a project can be in, and proposes an
admin-driven `Project::TypeSwitcher` flow with a preflight that either
resolves each side effect automatically, blocks, or asks the admin to choose.

---

## 1. How the distinction works today

**Source of truth:** `projects.hardware_stage`. `nil` = software,
`"design"` / `"build"` = hardware (`Project#hardware?`,
`Project::HARDWARE_STAGES`). `projects.project_type` ("Hardware", "Web App",
…) is an AI-assigned display category and is *not* consulted by any gate.

**The lock** (`Project#hardware_stage_locked_once_committed`): once the project
has any `Certification::FundingRequest` or any `Post::ShipEvent`, the stage
can't change. Three `attr_accessor` bypasses exist, each owned by one flow:

| accessor | set by | purpose |
|---|---|---|
| `advancing_via_funding_approval` | `FundingRequest#apply_verdict_to_project!` | design → build on approval |
| `converting_review_queue` | `Certification::Reviewable#confirm_queue_conversion!` | builder confirmed a design↔build misfile |
| `reverting_hardware_review` | `Certification::ReviewUndoer` | rewind build → design when an approval is undone |

**Second guard** (`Project#hardware_required_by_current_mission`): a project
attached to a hardware mission can't go software. The mission has to be
detached first.

**Existing "wrong queue" flow** (`Certification::Reviewable`
`flag_queue_mismatch!` / `confirm_queue_conversion!` / `dispute_queue_mismatch!`)
only moves between the two *hardware* queues (design funding ↔ build
certification). It has no notion of "this is software". Its shape (reviewer
flags → builder confirms or disputes → record is `withdrawn` and the project
moves) is exactly what we want to extend.

**Existing reversal tooling** (`Certification::ReviewUndoer`) already models
side effects as `Effect(action: :reverse | :block | :manual | :correction)`
with a read-only `preflight` and a locked `undo!`. It knows how to classify an
HCB grant (unreachable / cancelled / spent / unspent), a design kit, YSWS
reviews, and hardware-mission rewards. The type switcher should reuse these
classifications rather than duplicate them.

**Admin precedent** (`Admin::ProjectsController#force_state` /
`#update_ship_status`): admin overrides write a manual `PaperTrail::Version`
with `whodunnit` and appear on the admin project page's audit log partial.

---

## 2. Everything coupled to `hardware_stage`

Blast radius, grouped by what changes meaning when the flag flips. Each row
is something the switch must either handle or knowingly leave alone.

### 2.1 Review queues
- `Certification::Ship.software_only` vs `in_global_hardware_queue` /
  `in_hardware_mission_queue` select the *same* `certification_ship_reviews`
  rows by `projects.hardware_stage`. Flipping the project moves a pending ship
  review between queues with no row change. The reviewer claim
  (`reviewer_id` / `claim_expires_at`) should be released so the right queue's
  reviewer picks it up.
- `Certification::FundingRequest` only exists for hardware; the create
  validation requires `design_stage?`. A software project can never have a
  pending one, so software → hardware never has funding requests to handle.
- `Certification::Ship#gates_resubmission?` (action-item acknowledgement) is
  hardware-only. `notify_owner!` uses the hardware notification vs the
  software Slack DM. Slack channel posts
  (`post_verdict_to_hardware_review_channel!`, `post_approval_to_hardware_feed!`)
  are hardware-only.
- `Certification::Ship.find_by_external` returns nil for hardware projects, so
  the external review dashboard's decisions are silently ignored for hardware
  certs. A software cert that becomes hardware drops off that dashboard's
  effective control; a hardware cert that becomes software starts honouring it
  (the `ShipWebhookJob` fires for every first ship regardless of type, so the
  dashboard already has the row).
- Hardware missions review their own attached projects
  (`Admin::Missions::HardwareReviewsController`); `Mission::Submission
  .software_reviewable` filters by `missions.hardware`, not by the project.

### 2.2 Money
- **Payout rule.** `Post::ShipEvent::Payouts#hardware_payout?` reads
  `project.hardware?` *at payout time*. Hardware pays flat
  `HARDWARE_STARDUST_PER_HOUR` (5) with no votes and no 24h review window;
  software pays the vote-percentile curve after 12 countable votes, gated on
  the recipient's vote balance. `ready_for_payout` includes every approved
  unpaid hardware ship, so **a software ship that becomes hardware is paid on
  the next sweep**, and an approved hardware ship that becomes software stops
  being payable until it collects votes.
- **Payout basis snapshot.** If `payout_basis_locked_at` is set but `payout`
  is nil, the snapshot (`multiplier`, `payout_curve_version`,
  `payout_basis_vote_ids`) was computed under the old rule and must be cleared
  (`clear_payout_review`) so it re-locks under the new one.
- **Hours basis.** `hours_at_ship` / `hours` differ: hardware drops
  design-phase devlogs and anything before the first approved funding request
  (`hardware_payout_cutoff`), and prefers reviewed YSWS devlog minutes;
  software counts every devlog in the window capped at 10h each. Must
  `recalculate_hours_at_ship` on every unpaid ship.
- **Paid ships.** `payout` + `LedgerEntry` are immutable (offsetting entries
  only). A switch can't retroactively change what was paid; it can only warn.
- **Vote debt.** `Post::ShipEvent#decrement_user_vote_balance` charges
  `VOTE_COST_PER_SHIP` (18) on software ships only, and
  `vote_balance_blocked?` withholds software payouts from users in deficit.
  A converted ship has either been charged for a pool it will never enter, or
  not charged for one it is about to enter.
- **HCB card grant** (`FundingRequest#hcb_grant_hashid`). Real money on a
  card. `ReviewUndoer#grant_effect` already classifies unreachable / cancelled
  / spent / unspent and cancels via `HCBService.cancel_card_grant!`.
- **Design kit** (`FundingRequest#awards_design_kit?`, `prize_redemptions`).
  Unclaimed kits are just an approval that hasn't been redeemed; claimed kits
  are physical goods out the door.
- **Hardware mission rewards** (`Certification::Ship#collapse_mission_build_review!`
  → `Mission::Submission#grant_rewards!`): achievement + fixed stardust,
  reversible via `reverse_rewards!` while the submission is still approved.

### 2.3 Rating pool
- `Vote::Matchmaker` excludes hardware projects; `Vote::Assignment#refresh`
  already swaps out an assignment whose project turned hardware. Nothing to
  do for software → hardware beyond letting refresh run.
- `Post::ShipEvent.voteable` requires `payout: nil`, `hours_at_ship > 0`,
  demo + repo URLs, and non-static-prize. A hardware ship that becomes
  software enters the pool immediately if those hold.

### 2.4 Devlogs and time tracking
- `post_devlogs.phase` is stamped from `project.hardware_stage` at creation
  (`Projects::DevlogsController#create`) — `nil` for software. Only
  `hardware_payout?` ships read it. `Project#refile_design_devlogs_as_build!`
  exists for the "never needed funding" conversion.
- Hardware builders record Lapse timelapses under a seeded Hackatime project
  named after the title (`Project::EnsureHackatimeProjectsJob`, triggered by
  `became_hardware?` after commit). Software builders link their own Hackatime
  projects. Seeded links are harmless on a software project, and the job
  self-runs on software → hardware. No special handling.
- Devlog `duration_seconds` is already captured; the source (Lapse vs editor
  plugin) doesn't matter after the fact.

### 2.5 Missions
- `Project::MissionAttachment#hardware_mission_takes_hardware_project`: a
  hardware mission only accepts hardware projects; the reverse is allowed.
- A pending `Mission::Submission` on a hardware mission is invisible to the
  software mission queue and, after detach, to the hardware mission dash too
  — it would strand. Bypass semantics in `docs/missions-design.md` is
  soft-delete.
- `Mission::MigrateProjectsToHardwareJob` is the only existing bulk switch
  (software → hardware design, on mission flip) and skips locked projects
  with a warning.

### 2.6 YSWS / integrity / external sync
- `Certification::Ysws.with_integrity_check` treats hardware reviews as
  satisfied without a `Certification::Integrity`; software ones need a decided
  check. `Certification::YswsAirtableSyncJob` reads `project.hardware?` at sync
  time. A switched project should be flagged for resync so the Airtable row
  reflects the new type.
- `ExternalDashboard::OutboundAuditService` skips hardware certs.

### 2.7 Display / classification
- `projects.project_type == "Hardware"` is set by the AI classifier
  (`Project::TypeCheckJob`) and was used once to backfill `hardware_stage`.
  `USER_SELECTABLE_TYPES` excludes it. Keep it consistent: set it on
  software → hardware, clear and re-classify on hardware → software.
- The builder's project page reads `hardware_stage_locked?` to render a
  locked toggle, shows funding cards from `timeline_funding_requests`
  (pending / approved / returned), and shows the queue-mismatch card from
  `review_awaiting_queue_answer`.
- Gorse sync (`sync_to_gorse_later`) for the project and its ship posts.

---

## 3. State matrix

For each artifact the project can carry, what the switch does. "Auto" = done
inside the switch transaction; "Choice" = admin must pick; "Warn" = allowed
with an acknowledged note; "Block" = refused until fixed outside; "Override"
= blocked by default, admin may proceed with a mandatory written reason.

### 3.1 Hardware → software

| Artifact / state | Handling |
|---|---|
| Funding request `pending` | Auto: `status: :withdrawn`, claim released. Not a verdict (no `decided_at`, no bounty). Builder notified that the request was closed because the project is now software. |
| Funding request `misfiled` (builder owes a design↔build answer) | Auto: `status: :withdrawn`. The admin's decision supersedes the open question; the queue-mismatch card disappears because `review_awaiting_queue_answer` only finds misfiled rows. |
| Funding request `returned` (the motivating case) | Auto: no change. It stays as history on the timeline. Note that `has_any_funding_request?` stays true, so the builder-side toggle stays locked — correct, only admins flip from here. |
| Funding request `approved`, `approved_without_grant?` | Auto: no external effect. Leave `approved`; nothing to pull back. |
| Funding request `approved`, HCB grant, **unspent** | Auto with confirmation: cancel via `HCBService.cancel_card_grant!` inside the lock (last, so a failed cancel rolls back), clear `hcb_grant_hashid`, stamp `reversed_at`. Reuses `ReviewUndoer#grant_effect` classification. |
| Funding request `approved`, HCB grant, **spent** | Override: block by default with the spent summary. Admin may proceed with a reason; effect recorded as `:manual` "reconcile the grant in HCB". The remaining balance is still cancelled so no further spend is possible. |
| Funding request `approved`, HCB **unreachable** | Block. Can't classify live money; retry or cancel by hand first. |
| Funding request `approved`, kit **unclaimed** | Auto: withdraw the offer by marking `prizes_waived: true` so `unredeemed_prizes` is empty (see §6 check on the shop gate). |
| Funding request `approved`, kit **claimed** | Override with reason; `:manual` effect "kit already shipped". |
| Funding request `withdrawn` | Nothing. |
| Ship review `pending` (in hardware build queue) | Auto: release claim (`release_claim!`). The row now selects into `software_only`, i.e. it lands in the shipwright queue. Note in the effect that the external dashboard's decisions now apply to it. |
| Ship review `misfiled` (build → design question open) | Auto: put it back to `pending` and restore the ship event (`dispute_queue_mismatch!` semantics, unclaimed). It then flows into the software queue. |
| Ship review `returned` / project `needs_changes` | Auto: nothing. Builder reships as software. |
| Ship review `approved`, ship **unpaid**, basis not locked | Auto: `recalculate_hours_at_ship` (software counts all devlogs). Warn: the ship enters the rating pool and needs 12 votes; YSWS review stays. Choice: charge `VOTE_COST_PER_SHIP` now (default **on** — every software ship in the pool paid it). |
| Ship review `approved`, ship **unpaid**, basis **locked** | Auto: `clear_payout_review` then as above. |
| Ship review `approved`, ship **paid** (hardware flat rate) | Warn only. Payout and ledger are immutable; the ship is not voteable (payout present). If the admin wants a clawback they add an offsetting ledger entry by hand — link to the payout review page. |
| Hardware mission attached | Auto (required): detach the `Project::MissionAttachment` before the stage update so `hardware_required_by_current_mission` passes. Shown as an unconditional effect. |
| Hardware mission submission `awaiting_certification` / `pending` | Auto: soft-delete the submission (bypass semantics). Otherwise it strands in no queue. |
| Hardware mission submission `approved` (rewards granted) | Override with reason. Default action on override: `reverse_rewards!` if no prize claimed; `:manual` if a prize redemption exists. Mirrors `ReviewUndoer#mission_reward_delivered?`. |
| Devlogs with `phase` design/build | Auto: leave `phase` untouched (history). Warn: on software every devlog in the window is payable, including design-phase time. |
| Seeded Hackatime projects | Nothing. |
| `project_type == "Hardware"` | Auto: set to nil and enqueue `Project::TypeCheckJob`. |
| Pending fraud report | Warn, don't block. Queues already exclude flagged projects. |
| Soft-deleted project | Block. Restore first. |

### 3.2 Software → hardware

The admin must also choose the **target stage**. Guidance shown inline:
*design* if the builder still needs parts (unlocks a funding request);
*build* if parts are in hand or the thing is already built. Constraint: a
project with a pending or approved ship can't sensibly be *design*.

| Artifact / state | Handling |
|---|---|
| No ships, no reviews | Auto: set stage. `became_hardware?` seeds Hackatime projects. |
| Ship review `pending` (in software queue), target **build** | Auto: release claim; row moves to the hardware build queue. Post to the hardware review channel (`post_submission_to_hardware_review_channel!`) and invite the owner, since the queue notification never fired for it. Note: external dashboard decisions become no-ops. |
| Ship review `pending`, target **design** | Choice: (a) switch target to build and keep the ship; or (b) withdraw the ship the way the build→design queue conversion does — review `status: :withdrawn`, ship event `certification_status: "misfiled"` (the codebase's "withdrawn, off every public surface" status, which `last_ship_event` skips), then `Project#roll_back_withdrawn_ship!` so the project reads as unshipped and the builder can request funding and reship later. Default (a). |
| Ship review `approved`, ship **unpaid**, basis not locked | Auto: `recalculate_hours_at_ship`. **Warn loudly**: the next payout sweep pays this ship at 5 stardust/hour on all logged hours with no votes and no review window; show the estimated amount from `payout_preview`. Choice: refund `VOTE_COST_PER_SHIP` (default **on** — the builder paid for a pool the ship just left). Votes already cast stay on record but no longer matter. |
| Ship review `approved`, ship **unpaid**, basis **locked** (inside the 24h review window) | Auto: `clear_payout_review` first, then as above. |
| Ship review `approved`, ship **paid** (software curve) | Warn only, immutable. |
| Ship review `returned` | Auto: nothing; the reship will be reviewed as hardware. |
| Software (non-hardware) mission attached | Nothing — hardware projects may sit on software missions. Its pending submission keeps being reviewed by the mission team. |
| Vote assignments currently serving this ship | Nothing — `Vote::Assignment#refresh` replaces them. |
| `Certification::Integrity` on the ship | Nothing; hardware ignores it. |
| Devlogs (`phase: nil`) | Auto: leave. They count as build time on hardware (nil is "not design"). |
| `project_type` | Auto: set `"Hardware"`. |
| Owner not identity-verified / not YSWS-eligible | Nothing at switch time; the funding request form enforces it later. |

### 3.3 Hardware → hardware (design ↔ build)
Out of scope for the switcher UI: the builder-confirmed queue-mismatch flow
and `ReviewUndoer` already cover this. The switcher should refuse a
same-type target so it never becomes a back door around those flows.

---

## 4. Proposed design

### 4.1 `Project::TypeSwitcher` (service)

`app/services/project/type_switcher.rb`, modelled on `Certification::ReviewUndoer`.

```ruby
Project::TypeSwitcher.new(project, target:, actor:, options: {})
  #preflight  -> Outcome (read-only; safe from GET)
  #switch!    -> Outcome (performs; #switched?)
```

- `target` ∈ `:software`, `:design`, `:build`. Same-type target → block.
- `options` (all optional, validated against the preflight):
  - `pending_ship: :keep_as_build | :withdraw` (S→H with a pending ship and target design)
  - `adjust_vote_balance: true/false` (charge on H→S, refund on S→H)
  - `override: true` + `reason:` (required whenever any `:override` effect exists)
- `Effect` gains one action beyond the undoer's four: `:choice` (carries the
  option key, the allowed values and the default), and `:override` (a block
  the admin can lift with a reason). `Outcome#switchable?` is
  `blockers.empty? && (overrides.empty? || override_reason.present?) && choices_answered?`.
- `switch!` runs inside `project.with_lock`, re-runs a DB-only re-check
  (like `ReviewUndoer#still_undoable?`) so a concurrent verdict can't slip
  in, applies every in-DB effect via `update!` so PaperTrail records each
  one, then runs external reversals last (HCB cancel), raising
  `ActiveRecord::Rollback` on failure.
- Order inside the transaction: detach hardware mission → soft-delete
  stranded submissions → resolve funding requests → resolve ship reviews /
  ship events (release claims, clear payout basis, recalc hours) → vote
  balance adjustment (ledger-free; it's `users.vote_balance`) → the
  `hardware_stage` update itself → `project_type` → external calls.
- After commit: notify the builder, post to the hardware review channel when
  a ship moved into the build queue, enqueue `Project::TypeCheckJob` /
  Gorse sync / `flag_for_resync!` on the owner (YSWS Airtable).

### 4.2 Unlocking the stage validation

Replace the three boolean bypass accessors on `Project` with one:

```ruby
attr_accessor :hardware_stage_change_authorized_by
# :funding_approval | :queue_conversion | :review_undo | :admin_type_switch
```

`hardware_stage_locked_once_committed` returns early when it's set. The
three existing callers set the symbol instead of their boolean. This avoids
a fourth ad-hoc flag and makes the PaperTrail version's context greppable if
we later record it. Small mechanical refactor with existing test coverage
(`funding_request_test`, `review_undoer_test`, `hardware_queue_mismatch_test`).

### 4.3 Audit trail

No new table for v1 (avoids a migration). Two layers, both already surfaced
by `admin/shared/audit_log`:

1. Every record the switch touches is changed through `update!`, so
   PaperTrail versions land on the funding request, ship review, ship event,
   mission attachment / submission and project with `whodunnit` = the admin
   (controller runs under `set_paper_trail_whodunnit`).
2. One summary `PaperTrail::Version` on the project, `event: "type_switch"`,
   `object_changes: { hardware_stage: [old, new], reason:, options:, effects: [...] }`,
   mirroring `Admin::ProjectsController#update_ship_status`. This is the row
   an admin looks for to answer "who switched this and what happened".

If we later want a first-class history (e.g. show "Converted to software by X
on date" on the builder timeline), add `project_type_changes` then — with
user confirmation for the migration.

### 4.4 Admin UI

- **Entry point:** admin project page (`admin/projects/show`) Actions →
  "Change project type", plus contextual links from the hardware review
  page ("This is actually software…") and the software ship review page
  ("This is actually hardware…").
- **Step 1** `GET /admin/projects/:id/type_switch/new?target=…` — radio for
  the target (Software / Hardware · design / Hardware · build), then the
  preflight rendered as the same effects list `ReviewUndoer` uses (one line
  per effect, coloured by action), inline choice controls for `:choice`
  effects, an override checkbox + required reason textarea when `:override`
  effects exist, and the estimated hardware payout when relevant.
- **Step 2** `POST /admin/projects/:id/type_switch` — re-runs preflight with
  the submitted options; on success redirects back with the summary; on a
  blocker/conflict re-renders with the fresh preflight.
- **Policy:** `Admin::ProjectPolicy#switch_type?` → `user.admin?` only
  (fraud dept has `update?` but this moves money; keep it narrow).
- **Feature flag:** `:project_type_switch`, following `:hardware_review_undo`.
- Styling: Stardance tokens, BEM (`.type-switch__effect--block` etc.),
  reuse `ActionButtonComponent` and the `shared/modal` layout; the orange
  dashed admin marker per `docs/branding.md` §1.5.

### 4.5 Builder-facing side

- New `Notifications::Project::TypeChanged` (in-app + Slack + email, high
  priority, not aggregatable) explaining the new type, what was closed
  (funding request withdrawn / ship moved queues / kit offer withdrawn) and
  the next step ("request funding", "your ship is now with the software
  reviewers", "rate other projects to get your ship paid").
- Project page: the locked toggle already renders correctly from
  `hardware_stage_locked?`. The timeline keeps historical funding cards.
  Optional: a small system entry on the timeline ("Switched to software by
  the Stardance team") sourced from the `type_switch` version.

### 4.6 Phase 2 — reviewer flag → builder confirm (self-serve)

Extend the existing queue-mismatch flow with a third destination so the
motivating case never needs an admin:

- `flag_queue_mismatch!(reviewer:, reason:, suggested: :software)` on a
  funding request or hardware ship review, and `suggested: :hardware` on a
  software ship review. Store the suggestion (new nullable string column
  `suggested_queue` on both review tables — migration, needs confirmation;
  or derive from `internal_reason` prefix for a no-migration spike).
- `confirm_queue_conversion!` delegates to
  `Project::TypeSwitcher.new(project, target:, actor: owner).preflight`. If
  the outcome has no blockers, overrides or choices, apply it with defaults
  under `authorized_by: :queue_conversion`. If it needs a human, leave the
  review `misfiled`, tell the builder an admin will finish it, and DM the
  admin channel with a link to the admin flow.
- `dispute_queue_mismatch!` unchanged.
- `queue_mismatch_flagged_label` / `queue_mismatch_suggested_label` become
  data-driven so the notification and card copy read "software project"
  where appropriate.

Phase 1 (admin flow) ships first; Phase 2 reuses it entirely.

---

## 5. Edge cases and guards (checklist)

- **Same-type target** → block (use the existing flows).
- **Concurrent verdict**: a reviewer approves the funding request between
  preflight and POST → re-check under `project.with_lock` and re-render.
- **Reviewer holds a claim** on the moving review → `release_claim!`;
  `atomic_claim!` respects the pending status, nothing else to do.
- **Unique pending review per project** indexes are untouched (rows aren't
  duplicated, only re-selected).
- **`Project#has_any_funding_request?` memo** — the switcher must `reload`
  the project after touching requests; `Project#reload` already clears the
  memos.
- **Ship event `certification_status: "misfiled"`** left over from a
  hardware misfile → restore to `"pending"` before the switch, or the ship
  stays hidden from the feed forever (`HIDDEN_STATUSES`).
- **Project in `under_review` / `approved` AASM state with a pending review
  moving queues** → leave `ship_status` alone; the destination queue's
  verdict drives it as normal.
- **Multiple ship events** (reships): iterate every ship event, not just
  `last_ship_event`; only unpaid ones get hours recalculated / basis cleared.
- **Static-prize mission ship** (`payout_path: "static_prize"`) → never
  enters payout either way; no vote adjustment.
- **Owner changed** since the grant (owner membership transferred): grant
  recipient is `FundingRequest#owner`, which already falls back to `user`.
- **Deleted project** → block. **Pending fraud report** → warn.
- **Hardware mission attach after switch to software** — impossible by
  validation; fine.
- **Hackatime seeding for placeholder-titled projects** — the job already
  defers to the rename; nothing to do.
- **Time-of-check for HCB**: cached 90s in `ReviewUndoer#fetch_grant`;
  the switch must bypass the cache on `switch!` (fresh `show_card_grant`) or
  it could cancel a grant that was spent in the last minute.
- **Vote balance adjustment idempotency**: record it in the summary version
  and refuse a second switch within the same direction that would double
  charge/refund (check the last `type_switch` version's options).
- **Builder-side toggle** stays locked after a switch (funding request or
  ship still exists), so the admin decision can't be undone by the builder.

---

## 6. Things to verify while implementing

- The shop's free-price gate for a design kit: confirm it checks
  `approved?` (or `prizes_waived`) on the funding request, so a withdrawn or
  waived request offers no kit. `Mission::PrizeRedeemable#unredeemed_prizes`
  alone does not check status.
- `ExternalDashboard::ShipWebhookJob` idempotency, so we can safely re-fire
  it (or decide not to) when a hardware cert becomes software.
- `Certification::YswsAirtableSyncJob` behaviour when a review's project
  type changes after a sync (does it overwrite the type column on resync?).
- `Vote::Assignment#refresh` is only called on the voter's next visit; an
  approved hardware ship converted to software isn't served until the
  matchmaker runs — no action, just expectation-setting for the builder.

---

## 7. Test plan

Minitest, fixtures. New `test/services/project/type_switcher_test.rb`
covering each row of §3 as a unit (preflight classification + `switch!`
outcome + PaperTrail versions), an integration test
`test/integration/admin_project_type_switch_test.rb` for the two-step admin
flow (policy, flag, override reason required, concurrent-change re-render),
and extensions to `hardware_queue_mismatch_test.rb` for Phase 2. Stub
`HCBService.show_card_grant` / `cancel_card_grant!` the way
`review_undoer_test.rb` does.

## 8. Rollout

1. Refactor the stage-lock accessors (§4.2). No behaviour change.
2. `Project::TypeSwitcher` + tests, no UI.
3. Admin UI behind `:project_type_switch`; enable for the hardware review
   team; watch the audit log.
4. Builder notification.
5. Phase 2 reviewer flag → builder confirm, after the admin flow has handled
   a few real cases and the choice defaults have settled.
