require "test_helper"

class Projects::RecertificationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @owner = create_user(slack_id: "U_REC_OWNER", display_name: "rec-owner", verified: true)
    @project = Project.create!(title: "Returned build")
    @project.memberships.create!(user: @owner, role: :owner)
    @project.update!(ship_status: "needs_changes")

    sign_in @owner
  end

  test "a recert that ticks nothing is refused" do
    returned_review(feedback: "nearly there\n- photograph the solder joints")

    assert_no_difference -> { @project.ship_reviews.count } do
      post project_recertification_path(@project)
    end

    assert_equal "needs_changes", @project.reload.ship_status
  end

  test "a recert that ticks every action item goes through" do
    review = returned_review(feedback: "nearly there\n- photograph the solder joints")

    assert_difference -> { @project.ship_reviews.count }, 1 do
      post project_recertification_path(@project), params: acknowledging(review, indices: [ 0 ])
    end

    assert_equal "submitted", @project.reload.ship_status
  end

  private

  def reviewer
    @reviewer ||= begin
      user = create_user(slack_id: "U_REC_REV", display_name: "rec-rev")
      user.grant_role!(:admin)
      user
    end
  end

  def returned_review(feedback:)
    review = @project.ship_reviews.create!(status: :pending)
    review.update!(reviewer: reviewer, status: :returned, feedback: feedback)
    review
  end

  def acknowledging(review, indices:)
    {
      acknowledged_action_items: indices.map(&:to_s),
      action_items_digest: review.action_items_digest
    }
  end
end
