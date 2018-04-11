class RolesController < ApplicationController
  def index
    authorize Role
    @roles = policy_scope(Role)
  end
end
