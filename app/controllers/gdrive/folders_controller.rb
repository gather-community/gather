# frozen_string_literal: true

module GDrive
  class FoldersController < ApplicationController
    before_action -> { nav_context(:wiki, :gdrive) }

    def show
      authorize(:folder, policy_class: FoldersPolicy)
      @config = MainConfig.find_by(community: current_community)
      @setup_policy = SetupPolicy.new(current_user, current_community)
      if @config
        shared_drives = @config.shared_drives
        return @no_drives if shared_drives.none?
        multiple_drives = shared_drives.size > 1

        wrapper = Wrapper.new(config: @config, google_user_id: @config.org_user_id)
        return @not_authenticated unless wrapper.authenticated?

        if params[:drive]
          validate_gdrive_id(params[:folder_id])
          ancestors = [fetch_drive(wrapper, params[:folder_id])]
          @file_list = list_files(wrapper, params[:folder_id])
        elsif params[:folder_id]
          validate_gdrive_id(params[:folder_id])
          ancestors = find_ancestors(wrapper, params[:folder_id], multiple_drives: multiple_drives)
          @file_list = list_files(wrapper, params[:folder_id])
        elsif !multiple_drives
          ancestors = []
          @file_list = list_files(wrapper, shared_drives[0].external_id)
        else
          # At this point, we know there must be multiple shared drives, so we assemble a list of them.
          ancestors = []
          drives = []
          shared_drives.each do |drive|
            drives << wrapper.service.get_drive(drive.external_id, fields: "id,name")
          end
          @drive_list = Google::Apis::DriveV3::DriveList.new(drives: drives)
        end
        @ancestors_decorator = AncestorsDecorator.new(ancestors)
      end
    end

    private

    def validate_gdrive_id(gdrive_id)
      raise ArgumentError, "Invalid ID #{gdrive_id}" unless gdrive_id =~ /\A[A-Za-z0-9_\-]*\z/
    end

    def find_ancestors(wrapper, folder_id, multiple_drives:)
      ancestors = []
      ancestor_id = folder_id
      loop do
        folder = wrapper.service.get_file(ancestor_id, fields: "id,name,parents,driveId",
                                                       supports_all_drives: true)
        ancestors.unshift(folder)
        # If parent ID is the drive ID, we can stop searching and just add the drive as the top ancestor.
        # Although if multiple_drives is false we don't need to add the drive as an ancestor.
        if folder.parents[0] == folder.drive_id
          ancestors.unshift(fetch_drive(wrapper, folder.parents[0])) if multiple_drives
          break
        end
        ancestor_id = folder.parents[0]
      end
      ancestors
    end

    def fetch_drive(wrapper, drive_id)
      wrapper.service.get_drive(drive_id, fields: "id,name")
    end

    def list_files(wrapper, parent_id)
      wrapper.service.list_files(q: "'#{parent_id}' in parents",
                                 fields: "files(id,name,mimeType,iconLink,webViewLink)",
                                 order_by: "folder,name",
                                 supports_all_drives: true,
                                 include_items_from_all_drives: true)
    end
  end
end
