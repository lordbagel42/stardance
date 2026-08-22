module ActionItemGate
  extend ActiveSupport::Concern

  STALE_ALERT =
    "Your reviewer updated their feedback while you had this open. " \
    "Take another look at what they're asking for, then submit again.".freeze

  UNACKNOWLEDGED_ALERT =
    "Tick off everything your reviewer asked for before submitting again.".freeze

  private

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
