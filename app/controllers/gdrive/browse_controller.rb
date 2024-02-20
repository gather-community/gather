# frozen_string_literal: true

module GDrive
  class BrowseController < ApplicationController
    before_action -> { nav_context(:files, :gdrive) }

    def index
      @browse_decorator = BrowseDecorator.new

      begin
        authorize(:folder, policy_class: BrowsePolicy)
        @config = MainConfig.find_by(community: current_community)
        @setup_policy = SetupPolicy.new(current_user, current_community)
        if !@config
          skip_policy_scope
          return
        end

        @has_migration = MigrationConfig.find_by(community: current_community)&.operations&.any?

        wrapper = Wrapper.new(config: @config, google_user_id: @config.org_user_id,
          callback_url: gdrive_setup_auth_callback_url(host: Settings.url.host))
        unless wrapper.has_credentials?
          setup_auth_url(wrapper: wrapper)
          # If there are any items then this community has probably connected before but maybe
          # their refresh token expired, so we don't want to say they're not yet connected or they
          # might freak out.
          if @config.items.any?
            @authorization_error = true
          else
            @no_credentials = true
          end
        end

        # If there are no drives at all connected to the config, then we set a special flag and return.
        @drives = @config.items.drives_only
        if @drives.none?
          skip_policy_scope
          return @no_drives = true
        end

        # From this point on, we only consider drives the user can actually see.
        # If they can't see any, we react differently than if there are none at all connected to the config.
        @drives = policy_scope(@drives).reject { |d| d.error_type.present? }
        return @no_accessible_drives = true if @drives.none?
        multiple_drives = @drives.size > 1

        # In the below, we use ItemPolicy on the containing drive to determine whether the user can
        # view something. If a user can a drive, then they can read any file/folder in it.
        # It's possible that a user could read a file/folder without being able to read the drive,
        # but in that case, they wouldn't be able to navigate to it with Gather anyway, since navigation
        # starts from the drive level. And it would not be a recommended setup. We also warn about this
        # on the settings page.
        #
        # When we later add the ability to create a file/folder, we may need to change this setup
        # because we will need to check if the user can create an item inside the current folder, and
        # that may be more nuanced.

        # Drive accessed explicitly by ID
        if params[:drive] && params[:item_id]
          validate_gdrive_id(params[:item_id])
          return render_not_found unless can_read_drive?(params[:item_id])
          ancestors = find_ancestors(wrapper: wrapper, drive_id: params[:item_id],
            multiple_drives: multiple_drives)
          @file_list = list_files(wrapper, params[:item_id])
          @browse_decorator.item_url = "https://drive.google.com/drive/folders/#{params[:item_id]}"

        # Folder accessed explicitly by ID
        elsif params[:item_id]
          validate_gdrive_id(params[:item_id])
          ancestors = find_ancestors(wrapper: wrapper, folder_id: params[:item_id],
            multiple_drives: multiple_drives)
          return render_not_found unless can_read_drive?(ancestors[-1].drive_id)
          @file_list = list_files(wrapper, params[:item_id])
          @browse_decorator.item_url = "https://drive.google.com/drive/folders/#{params[:item_id]}"

        # No ID given; list all accessible drives
        else
          # We don't need to call can_read_drive? in this branch
          # because we fetched the drive list using policy_scope.
          DriveSyncer.new(wrapper, @drives).sync
          ancestors = []
          unless multiple_drives
            # At this point there must be exactly one shared drive.
            # If there is only one drive, we don't need to show it as ancestor.
            @file_list = list_files(wrapper, @drives[0].external_id)
            @browse_decorator.item_url = "https://drive.google.com/drive/folders/#{@drives[0].external_id}"
          end
        end
        @ancestors_decorator = AncestorsDecorator.new(ancestors)
      rescue Google::Apis::AuthorizationError
        # The token for this config (MainConfigs should only have one) is no good anymore
        # so we destroy it so that when they go to setup they can re-connect.
        @config.tokens.destroy_all
        @authorization_error = true
      rescue Google::Apis::ClientError => error
        if error.message.include?("File not found")
          render_not_found
        else
          raise error
        end
      end
    end

    private

    def validate_gdrive_id(gdrive_id)
      raise ArgumentError, "Invalid ID #{gdrive_id}" unless /\A[A-Za-z0-9_-]*\z/.match?(gdrive_id)
    end

    def setup_auth_url(wrapper:)
      state = {community_id: current_community.id}
      @auth_url = wrapper.get_authorization_url(request: request, state: state,
        redirect_to: gdrive_home_url)
    end

    def find_ancestors(wrapper:, multiple_drives:, folder_id: nil, drive_id: nil)
      ancestors = []
      if folder_id
        ancestor_id = folder_id
        loop do
          folder = wrapper.get_file(ancestor_id, fields: "id,name,parents,driveId",
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
      DriveSyncer.new(wrapper, Item.find_by!(external_id: drive_id)).sync
    end

    def list_files(wrapper, parent_id)
      parent_id = parent_id.gsub("'") { "\\'" }
      wrapper.list_files(q: "'#{parent_id}' in parents and trashed = false",
        fields: "files(id,name,mimeType,iconLink,webViewLink)",
        order_by: "folder,name",
        supports_all_drives: true,
        include_items_from_all_drives: true)
    end

    def can_read_drive?(drive_id)
      drive = Item.find_by(external_id: drive_id, kind: "drive")
      return false if drive.nil? || drive.error_type.present?
      ItemPolicy.new(current_user, drive).show?
    end
  end
end
