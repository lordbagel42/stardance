class HomePolicy < ApplicationPolicy
  def index?
    signed_in_any?
  end

  def feed?
    index?
  end
end
