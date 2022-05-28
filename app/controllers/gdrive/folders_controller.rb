# frozen_string_literal: true

module GDrive
  class FoldersController < ApplicationController
    before_action -> { nav_context(:wiki, :gdrive) }

    def show
      authorize(:folder, policy_class: FoldersPolicy)
      @config = GDrive::Config.find_by(community: current_community)
      @auth_policy = GDrive::AuthPolicy.new(current_user, current_community)
    end
  end
end
