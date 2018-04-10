class RolesController < ApplicationController
  def index
    @roles = []#policy_scope(Role)
  end
end
