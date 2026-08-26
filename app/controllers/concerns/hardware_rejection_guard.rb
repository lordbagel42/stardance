# frozen_string_literal: true

# Builder submission controllers include this to refuse any new submission on a
# permanently-rejected hardware project. A permanent rejection is terminal: the
# project can never be submitted again in any form (design funding, ship, or
# re-certification). See Project#hardware_permanently_rejected?.
module HardwareRejectionGuard
  extend ActiveSupport::Concern

  PERMANENTLY_REJECTED_ALERT =
    "This project was permanently rejected and can't be submitted again."

  private

  # Redirects and returns true when the project is permanently rejected, so the
  # caller can `return if permanently_rejected_block(@project)`.
  def permanently_rejected_block(project)
    return false unless project&.hardware_permanently_rejected?

    redirect_to project_path(project), alert: PERMANENTLY_REJECTED_ALERT
    true
  end
end
