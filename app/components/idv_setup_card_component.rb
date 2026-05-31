# frozen_string_literal: true

# Body of the "verify your identity" popup (shared/_idv_verify_modal), opened
# from the IDV badge/alert when the user hasn't completed identity verification.
# Tone matches the link-account screen — reassure, explain why, and link to
# authoritative resources.
class IdvSetupCardComponent < ViewComponent::Base
  attr_reader :user, :return_to, :dom_id

  def initialize(user:, return_to: nil, dom_id: "idv-setup")
    @user = user
    @return_to = return_to
    @dom_id = dom_id
  end

  def render?
    user.present? && (!user.identity_verified? || ysws_ineligible?)
  end

  def status_eyebrow
    return "account needed" if needs_hca_link?
    return "not eligible for prizes" if ysws_ineligible?

    case user.verification_status
    when "pending"     then "we're reviewing"
    when "ineligible"  then "something went wrong"
    else                    "your work isn't public yet"
    end
  end

  def title
    return "Link your Hack Club Account first." if needs_hca_link?
    return "You're verified, but not eligible for YSWS yet." if ysws_ineligible?

    case user.verification_status
    when "pending"     then "Hold tight — we're verifying your identity."
    when "ineligible"  then "We couldn't verify your identity."
    else                    "Verify your identity to share your work."
    end
  end

  def needs_hca_link?   = !user.hca_linked?
  def pending?          = user.verification_pending?
  def ineligible?       = user.verification_ineligible?
  def ysws_ineligible?  = user.identity_verified? && !user.ysws_eligible?

  def verify_url
    base = return_to.presence || helpers.request.original_url
    return_with_status = if base.include?("?")
      "#{base}&portal_status=1"
    else
      "#{base}?portal_status=1"
    end
    HCAService.verify_portal_url(return_to: return_with_status)
  end
end
