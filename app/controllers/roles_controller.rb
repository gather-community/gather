class RolesController < ApplicationController
  before_action -> { nav_context(:people, :roles) }

  def index
    authorize Role
    @roles = policy_scope(Role)
    @roles = @roles.sort_by { |x| User::ROLES.index(x) } # this doesn't seem to work
  end
end
