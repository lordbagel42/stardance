import { Controller } from "@hotwired/stimulus";

// Holds a resubmission until the builder has ticked every action item their
// reviewer left. Goes on the form; the boxes live in projects/_action_items.
//
// The submit button starts enabled in the markup and is disabled here on
// connect, never server-side: a builder whose JS never runs has to still be able
// to press it and be turned down by ActionItemGate, rather than face a button
// that can never enable itself. The same gate is enforced server-side, so
// nothing here is load-bearing for correctness - it just saves a round trip.
export default class extends Controller {
  static targets = ["checkbox", "error", "progress", "submit"];

  connect() {
    this.report();
  }

  report() {
    if (this.hasProgressTarget) {
      const total = this.checkboxTargets.length;
      this.progressTarget.textContent = `${this.tickedCount} of ${total} confirmed`;
    }

    this.syncSubmit();
    if (this.allTicked) this.clearError();
  }

  syncSubmit() {
    if (!this.hasSubmitTarget) return;

    // The funding form has more to say about its own button than this does — a
    // tier, an amount inside that tier, the BOM confirmed — and it already
    // accounts for the checklist, so it stays the single authority there.
    // Enabling on "all ticked" alone would let a request through with no tier.
    const form = this.element.closest("form") || this.element;
    if (form.dataset.tierMaxes && typeof window.fundingValidate === "function") {
      window.fundingValidate(form);
      return;
    }

    this.submitTarget.disabled = !this.allTicked;
  }

  // Backstop for the case where something else re-enabled the button.
  guard(event) {
    if (this.allTicked) return;

    event.preventDefault();

    if (this.hasErrorTarget) {
      this.errorTarget.textContent =
        "Confirm each change your reviewer asked for before submitting again.";
      this.errorTarget.hidden = false;
    }

    const pending = this.checkboxTargets.find((box) => !box.checked);
    if (pending) pending.focus();
  }

  clearError() {
    if (this.hasErrorTarget) this.errorTarget.hidden = true;
  }

  get tickedCount() {
    return this.checkboxTargets.filter((box) => box.checked).length;
  }

  get allTicked() {
    return this.checkboxTargets.every((box) => box.checked);
  }
}
