class RolesController < ApplicationController

  before_action -> { nav_context(:people, :roles) }, except: :accounts

  def index
    authorize Role
    @roles = policy_scope(Role)
    @roles = @roles.sort_by { |x| User::ROLES.index(x) } #this doesn't seem to work
  end
end
