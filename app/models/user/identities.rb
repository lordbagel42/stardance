module User::Identities
  extend ActiveSupport::Concern

  class_methods do
    def find_by_hackatime(uid) = User::Identity.hackatime.find_by(uid:)&.user
  end

  def has_identity_linked? = !verification_needs_submission?

  def setup_complete?
    hackatime_identity.present? && has_identity_linked?
  end
end
