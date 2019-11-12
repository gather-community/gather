# frozen_string_literal: true

# Controller for roles actions. Currently just for displaying who's in what role.
class RolesController < ApplicationController
  before_action -> { nav_context(:people, :roles) }

  def index
    authorize(User)
    @users_by_role = Hash.new { |h, k| h[k] = [] }
    policy_scope(User).in_community(current_community).includes(:roles).active.by_name.each do |u|
      role_names = u.roles.map { |r| r.name.to_sym }
      # The user doesn't care about the distinction between different admin types.
      role_names = role_names.map { |r| User::ADMIN_ROLES.include?(r) ? :admin : r }.uniq
      role_names.each { |r| @users_by_role[r] << u }
    end
    @roles = (User::ROLES - User::ADMIN_ROLES).insert(0, :admin)
  end
end
