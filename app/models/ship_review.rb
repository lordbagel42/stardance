class ShipReview < ApplicationRecord
  include Reviewable

  belongs_to :project
  belongs_to :reviewer, class_name: "User", optional: true

  has_paper_trail

  enum :status, {
    pending: 0,
    approved: 1,
    returned: 2
  }, default: :pending

  validates :feedback, length: { maximum: 10_000 }, allow_blank: true
  validates :internal_reason, length: { maximum: 10_000 }, allow_blank: true

  scope :for_reviewer, ->(user) {
    joins(:project)
      .where(projects: { deleted_at: nil })
      .where.not(project_id: user.memberships.select(:project_id))
  }

  def self.available_for(user)
    super(user).merge(for_reviewer(user))
  end

  after_save :sync_project_state!, if: :saved_change_to_status?
  after_save_commit :notify_owner!, if: -> { saved_change_to_status? && !pending? }

  private

  def sync_project_state!
    return if pending?
    project.with_lock do
      project.start_review! if project.may_start_review?
      case status.to_sym
      when :approved
        project.approve! if project.may_approve?
        project.last_ship_event&.update!(certification_status: "approved")
      when :returned
        project.return_for_changes! if project.may_return_for_changes?
      end
    end
  end

  def notify_owner!
    owner = project.memberships.owner.first&.user
    return unless owner&.slack_id.present?

    case status.to_sym
    when :approved
      owner.dm_user("Your project '#{project.title}' was approved. It's out for voting now.")
    when :returned
      msg = "Your project '#{project.title}' needs changes before it can ship."
      msg += "\n\n#{feedback}" if feedback.present?
      owner.dm_user(msg)
    end
  end
end
