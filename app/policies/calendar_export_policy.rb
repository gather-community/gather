class CalendarExportPolicy < ApplicationPolicy

  def index?
    active?
  end

  def show?
    index?
  end

  def reset_token?
    index?
  end

  protected

  def allow_class_based_auth?
    true
  end
end
