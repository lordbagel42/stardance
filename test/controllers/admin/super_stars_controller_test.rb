require "test_helper"

class Admin::SuperStarsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = User.create!(slack_id: "U_SS_ADMIN", display_name: "ss_admin", email: "ss_admin@example.test")
    @admin.grant_role!(:admin)
    @nominator = User.create!(slack_id: "U_SS_NOM", display_name: "ss_nominator", email: "ss_nominator@example.test")

    @pending = Project.create!(title: "Pending Nominee", nominated_fire_at: 1.day.ago, nominated_fire_by: @nominator)
    @starred = Project.create!(title: "Already Starred", marked_fire_at: 2.days.ago, marked_fire_by: @admin)
  end

  test "admin sees pending nominations and current super stars" do
    sign_in @admin

    get admin_super_stars_path

    assert_response :success
    assert_select "td", text: "Pending Nominee"
    assert_select "td", text: "Already Starred"
  end

  test "non-admin cannot access the page" do
    sign_in @nominator

    get admin_super_stars_path

    assert_response :not_found
  end
end
