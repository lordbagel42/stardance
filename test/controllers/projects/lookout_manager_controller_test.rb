require "test_helper"

class Projects::LookoutManagerControllerTest < ActionDispatch::IntegrationTest
  setup do
    Flipper.enable(:lookout_manager)
    @owner = create_user(slack_id: "U_LM_OWNER", display_name: "lm_owner")
    @project = Project.create!(title: "Robot arm", hardware_stage: "build")
    @project.memberships.create!(user: @owner, role: :owner)
  end

  test "index returns 404 when flag is off" do
    Flipper.disable(:lookout_manager)
    sign_in @owner

    get project_lookout_manager_index_path(@project)

    assert_response :not_found
  end

  test "index is rejected for a non-member" do
    stranger = create_user(slack_id: "U_LM_STRANGER", display_name: "lm_stranger")
    sign_in stranger

    get project_lookout_manager_index_path(@project)

    assert_response :forbidden
  end

  test "index renders with no unassigned sessions" do
    @project.lookout_sessions.create!(
      user: @owner,
      token: "tok-forwarded",
      status: "complete",
      duration_seconds: 600,
      hackatime_forwarded_at: Time.current
    )
    sign_in @owner

    get project_lookout_manager_index_path(@project)

    assert_response :success
    assert_select ".lookout-manager__empty"
    assert_select ".lookout-manager__row", count: 0
  end

  test "index lists unassigned complete sessions for the current user" do
    session = @project.lookout_sessions.create!(
      user: @owner,
      token: "tok-unassigned",
      status: "complete",
      duration_seconds: 900
    )
    sign_in @owner

    get project_lookout_manager_index_path(@project)

    assert_response :success
    assert_select "##{dom_id(session)}"
  end
end
