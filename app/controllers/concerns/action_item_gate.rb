# Refuses a resubmission until the builder has ticked every action item their
# reviewer left (see Certification::Reviewable for the dashed-list syntax).
#
# Shared by both hardware resubmit paths - design funding and build
# re-certification - which differ only in which review carries the checklist.
# The client-side controller already disables the submit button until every box
# is ticked; this is the half that holds when someone skips the form.
module ActionItemGate
  extend ActiveSupport::Concern

  STALE_ALERT =
    "Your reviewer updated their feedback while you had this open. " \
    "Take another look at what they're asking for, then submit again.".freeze

  UNACKNOWLEDGED_ALERT =
    "Tick off everything your reviewer asked for before submitting again.".freeze

  private

  # True when the resubmission was refused, in which case a redirect has already
  # been issued and the caller must return without doing any work. Expects
  # @project to be set, which both resubmit paths do before calling.
  def action_items_block_resubmission?(review)
    return false unless review&.returned?

    alert = case review.action_items_blocker(
              acknowledged: params[:acknowledged_action_items],
              digest: params[:action_items_digest]
            )
    when :stale then STALE_ALERT
    when :unacknowledged then UNACKNOWLEDGED_ALERT
    end
    return false if alert.nil?

    redirect_to project_path(@project), alert: alert
    true
  end
end
