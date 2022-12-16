# frozen_string_literal: true

module GDrive
  class FoldersController < ApplicationController
    before_action -> { nav_context(:wiki, :gdrive) }

    def show
      authorize(:folder, policy_class: FoldersPolicy)
      @config = MainConfig.find_by(community: current_community)
      @setup_policy = SetupPolicy.new(current_user, current_community)
      # if @config
      #   folder_id = params[:folder_id].presence || @config.folder_id
      #   wrapper = Wrapper.new(config: @config, google_user_id: @config.org_user_id)
      #   @ancestors = find_ancestors(wrapper, folder_id)
      #   @file_list = wrapper.service.list_files(q: "'#{folder_id}' in parents",
      #                                           fields: "files(id,name,mimeType,iconLink,webViewLink)",
      #                                           order_by: "folder,name")
      # end
    end

    private

    def find_ancestors(wrapper, folder_id)
      ancestors = []
      ancestor_id = folder_id
      loop do
        break if ancestor_id == @config.folder_id
        ancestors.unshift(wrapper.service.get_file(ancestor_id, fields: "id,name,parents"))
        ancestor_id = ancestors.first.parents[0]
      end
      ancestors
    end
  end
end
