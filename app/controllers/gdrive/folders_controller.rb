# frozen_string_literal: true

module GDrive
  class FoldersController < ApplicationController
    before_action -> { nav_context(:wiki, :gdrive) }

    def show
      authorize(:folder, policy_class: FoldersPolicy)
      @config = MainConfig.find_by(community: current_community)
      @setup_policy = SetupPolicy.new(current_user, current_community)
      return unless @config

      wrapper = Wrapper.new(config: @config, google_user_id: @config.org_user_id)
      return @no_auth = true unless wrapper.authenticated?

      # If there are no drives at all connected to the config, then we set a special flag and return.
      @items = @config.items
      return @no_drives = true if @items.none?

      # From this point on, we only consider drives the user can actually see.
      # If they can't see any, we react differently than if there are none at all connected to the config.
      @items = policy_scope(@items)
      return @no_accessible_drives = true if @items.none?
      multiple_drives = @items.size > 1

      if params[:drive] && params[:folder_id]
        validate_gdrive_id(params[:folder_id])
        return render_not_found unless can_read_item?(params[:folder_id])
        ancestors = find_ancestors(wrapper: wrapper, drive_id: params[:folder_id],
                                   multiple_drives: multiple_drives)
        @file_list = list_files(wrapper, params[:folder_id])
      elsif params[:folder_id]
        validate_gdrive_id(params[:folder_id])
        ancestors = find_ancestors(wrapper: wrapper, folder_id: params[:folder_id],
                                   multiple_drives: multiple_drives)
        return render_not_found unless can_read_item?(ancestors[-1].drive_id)
        @file_list = list_files(wrapper, params[:folder_id])
      else
        # We don't need to call authorize_item_by_id in this branch
        # because we fetched the drive list using policy_scope.
        ItemSyncer.new(wrapper, @items).sync
        ancestors = []
        unless multiple_drives
          # At this point there must be exactly one shared drive.
          # If there is only one drive, we don't need to show it as ancestor.
          @file_list = list_files(wrapper, @items[0].external_id)
        end
      end
      @ancestors_decorator = AncestorsDecorator.new(ancestors)
    rescue Google::Apis::ClientError => error
      if error.message.include?("File not found")
        render_not_found
      else
        raise error
      end
    end

    private

    def validate_gdrive_id(gdrive_id)
      raise ArgumentError, "Invalid ID #{gdrive_id}" unless gdrive_id =~ /\A[A-Za-z0-9_\-]*\z/
    end

    def find_ancestors(wrapper:, folder_id: nil, drive_id: nil, multiple_drives:)
      ancestors = []
      if folder_id
        ancestor_id = folder_id
        loop do
          folder = wrapper.service.get_file(ancestor_id, fields: "id,name,parents,driveId",
                                                         supports_all_drives: true)
          ancestors.unshift(folder)
          # If parent ID is the drive ID, we can stop searching.
          ancestor_id = folder.parents[0]
          break if ancestor_id == folder.drive_id
        end
      else
        ancestor_id = drive_id
      end
      # At this point, ancestor_id has to be a shared drive ID.
      # We add it as an ancestor if we are in multiple drive mode.
      ancestors.unshift(fetch_drive(wrapper, ancestor_id)) if multiple_drives
      ancestors
    end

    def fetch_drive(wrapper, drive_id)
      ItemSyncer.new(wrapper, Item.find_by!(external_id: drive_id)).sync
    end

    def list_files(wrapper, parent_id)
      wrapper.service.list_files(q: "'#{parent_id}' in parents",
                                 fields: "files(id,name,mimeType,iconLink,webViewLink)",
                                 order_by: "folder,name",
                                 supports_all_drives: true,
                                 include_items_from_all_drives: true)
    end

    def can_read_item?(drive_id)
      drive = Item.find_by!(external_id: drive_id)
      ItemPolicy.new(current_user, drive).show?
    end
  end
end
