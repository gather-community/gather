class RolePolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      if active?
        Role.all
      else
        scope.none
      end
    end
  end

  def index?
    active?
  end
end
