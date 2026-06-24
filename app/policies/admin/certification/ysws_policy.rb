class Admin::Certification::YswsPolicy < ApplicationPolicy
  def index?
    return true if user.nil? # temp bypass for dev
    user.admin? || user.has_role?(:guardian_of_integrity)
  end

  def show?
    index?
  end

  def dashboard?
    index?
  end

  def update?
    index?
  end

  def report_fraud?
    index?
  end
end
