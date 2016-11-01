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
end
