require "test_helper"

class User::FunnelTest < ActiveSupport::TestCase
  setup { @user = users(:one) }

  test "a brand-new user is at :signed_up, entered at created_at" do
    created = @user.created_at
    stub_funnel(signed_up: created) do
      assert_equal :signed_up, @user.funnel_stage
      assert_equal created, @user.funnel_stage_entered_at
    end
  end

  test "reports the furthest reached step and when it was entered" do
    devlog_at = 3.days.ago
    stub_funnel(
      signed_up: 10.days.ago,
      onboarded: 9.days.ago,
      project_created: 5.days.ago,
      devlog_posted: devlog_at
    ) do
      assert_equal :devlog_posted, @user.funnel_stage
      assert_equal devlog_at, @user.funnel_stage_entered_at
    end
  end

  test "picks the highest-ordered step even when earlier steps were skipped" do
    hca_at = 2.days.ago
    # HCA linked but no project created — funnel order, not recency, decides.
    stub_funnel(signed_up: 8.days.ago, hca_linked: hca_at) do
      assert_equal :hca_linked, @user.funnel_stage
      assert_equal hca_at, @user.funnel_stage_entered_at
    end
  end

  private

  # The per-step timestamps come from six different associations; stub them so
  # the test exercises the ordering logic, not fixture plumbing. Assertions run
  # inside the yielded block, while the stub is in place.
  def stub_funnel(timestamps, &block)
    full = User::Funnel::STAGES.index_with { nil }.merge(timestamps)
    @user.stub(:funnel_step_timestamps, full, &block)
  end
end
