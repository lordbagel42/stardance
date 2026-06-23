# frozen_string_literal: true

class StreakBadgeComponent < ViewComponent::Base
  attr_reader :user

  def initialize(user:)
    @user = user
  end

  def render?
    user.present? && streak_days >= 2
  end

  def tooltip
    "#{streak_days}-day streak"
  end

  def streak_days
    @streak_days ||= user.current_streak
  end
end
