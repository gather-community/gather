# frozen_string_literal: true

# Controller for roles actions. Currently just for displaying who's in what role.
class RolesController < ApplicationController
  before_action -> { nav_context(:people, :roles) }

  def index
    authorize User
    @users_by_role = Hash.new { |h, k| h[k] = [] }
    policy_scope(User).in_community(current_community).includes(:roles).active.by_name.each do |u|
      u.roles.each { |r| @users_by_role[r.name.to_sym] << u }
    end
  end
end
