class RolesController < ApplicationController

  before_action -> { nav_context(:people, :roles) }, except: :accounts

  def index
    authorize Role
    @roles = policy_scope(Role)
  end
end
