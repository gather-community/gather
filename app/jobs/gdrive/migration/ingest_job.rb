# frozen_string_literal: true

module GDrive
  module Migration
    # Ingests selected files by moving them to their new homes.
    class IngestJob < BaseJob
      retry_on Google::Apis::ServerError

      class IngestFailedError < StandardError
      end

      MAX_ERRORS = 5

      attr_accessor :request, :operation, :main_wrapper, :migration_wrapper,
        :ancestor_tree_duplicator

      def perform(cluster_id:, request_id:)
        ActsAsTenant.with_tenant(Cluster.find(cluster_id)) do
          self.request = Request.find(request_id)
          self.operation = request.operation

          main_config = MainConfig.find_by!(community_id: operation.community_id)
          self.main_wrapper = Wrapper.new(config: main_config, google_user_id: main_config.org_user_id)
          migration_config = request.config
          self.migration_wrapper = Wrapper.new(config: migration_config, google_user_id: @request.google_email)
          self.ancestor_tree_duplicator = AncestorTreeDuplicator.new(wrapper: main_wrapper,
            operation: operation)

          operation.log(:info, "IngestJob starting",
            request_id: request.id,
            file_ids: request.ingest_file_ids)

          ensure_temp_drive
          ingest_files
          files_remaining = File.pending.owned_by(request.google_email).count
          status = files_remaining.zero? ? "done" : "in_progress"
          request.update!(status: status, ingest_status: "done", file_count: files_remaining)
        rescue IngestFailedError
          # This is raised in the error handling method in order to halt the ingestion
          # and not overwrite the status. If we get this error, we don't need to update statuses,
          # just the file count.
          files_remaining = File.pending.owned_by(request.google_email).count
          request.update!(file_count: files_remaining)
        end
      end

      private

      # This is a separate class method so we can stub it in tests.
      def self.random_request_id
        SecureRandom.uuid
      end

      def ensure_temp_drive
        return if request.temp_drive_id.present?

        temp_drive = Google::Apis::DriveV3::Drive.new(name: "Migration Temp Drive #{request.id}")
        operation.log(:info, "Creating temp drive", name: temp_drive.name)

        # This could only fail if our permissons are bad, which means the whole operation is broken.
        # So we let it bubble up and stop the job.
        temp_drive = main_wrapper.create_drive(self.class.random_request_id, temp_drive)

        # This could only fail if our permissons are bad, which means the whole operation is broken.
        # So we let it bubble up and stop the job.
        operation.log(:info, "Adding temp drive write permission", requestee: request.google_email)
        permission = Google::Apis::DriveV3::Permission.new(type: "user", email_address: request.google_email,
          role: "writer")
        main_wrapper.create_permission(temp_drive.id, permission, supports_all_drives: true, send_notification_email: false)

        request.update!(temp_drive_id: temp_drive.id)
      end

      def ingest_files
        request.ingest_file_ids.each do |file_id|
          operation.log(:info, "Ingesting file", file_id: file_id)
          direct_match = operation.files.find_by(external_id: file_id, status: "pending")
          shortcuts = operation.files.where(shortcut_target_id: file_id, status: "pending").to_a

          operation.log(:info, "Found #{direct_match ? 1 : 0} direct match, #{shortcuts.size} shortcuts")

          all_matches = [direct_match].concat(shortcuts).compact

          if all_matches.empty?
            operation.log(:warn, "No matches for file ID", file_id: file_id, requestee: request.google_email)
            next
          end

          owned_matches, unowned_matches = all_matches.partition { |f| f.owner == request.google_email }

          if owned_matches.empty?
            operation.log(:warn, "All matches for file ID owned by someone else", file_id: file_id,
              requestee: request.google_email, matched_ids: owned_matches.map(&:external_id))
            next
          end

          unowned_matches.each do |unowned_match|
            operation.log(:info, "Skipping match because owned by someone else",
              file_id: unowned_match.external_id,
              owner: unowned_match.owner,
              is_shortcut: unowned_match.external_id != file_id)
          end

          owned_matches.each_with_index do |migration_file, index|
            operation.log(:info, "Migrating file", file_id: file_id,
              is_shortcut: migration_file.external_id != file_id)

            # We only want to increment the counter shown in the loading indicator once per
            # picked file.
            migrate_file(migration_file, should_increment: index == 0)
          end
        end
      end

      # This method:
      # - Ensures the destination folder exists
      # - Moves file to temp drive
      # - Moves file to final location
      # - Updates file and migration request records with status
      # - Handles errors
      def migrate_file(migration_file, should_increment:)
        file_id = migration_file.external_id
        begin
          # This could fail if
          # 1. the folder map for migration_file.parent_id is missing or invalid AND
          #   1a. the workspace user doesn't have access to src_folder
          #   1b. the workspace user has access to src_folder but not its parents
          # We need to handle these possibilities and fail gracefully.
          dest_parent_id = ancestor_tree_duplicator.ensure_tree(migration_file.parent_id)
        rescue AncestorTreeDuplicator::ParentFolderInaccessible => error
          handle_file_error(migration_file, error, "ancestor_inaccessible", should_increment: should_increment)
          return
        rescue Google::Apis::ClientError => error
          handle_file_error(migration_file, error, "client_error_ensuring_tree", should_increment: should_increment)
          return
        end

        if dest_parent_id.nil?
          operation.log(:error, "dest_parent_id was nil, aborting", file_id: file_id)
          raise "dest_parent_id should never be nil"
        end

        # Move the file to the temp drive by removing the old parent and adding the temp drive.
        # This transfers ownership.
        # We think this could only fail if:
        # - The file is a shortcut that we haven't been granted permission for yet from the picker (this
        #   can happen normally so we swallow this error).
        # - The temp drive got deleted, very unlikely.
        # - The file got deleted or moved or permissions changed between when the user
        #   picked it and when the job runs, very unlikely.
        # Still, there may be other failure modes we haven't thought of so we don't want to fail the job.
        # So we log and persist the error and keep going.
        begin
          operation.log(:info, "Moving file to temp drive.", file_id: file_id)
          migration_wrapper.update_file(file_id, add_parents: request.temp_drive_id,
            remove_parents: migration_file.parent_id, supports_all_drives: true)
        rescue Google::Apis::ClientError => error
          if error.message.include?("The user has not granted the app")
            operation.log(:info, "Got 'The user has not granted the app' error, swallowing", file_id: file_id)
          else
            handle_file_error(migration_file, error, "client_error_moving_to_temp_drive", report: true, should_increment: should_increment)
          end
          return
        end

        # Move the file again to its proper home. The migration_wrapper can't do this because
        # the migrating user may not have permission.
        # We think this could only fail if:
        # - dest_parent got deleted. This is not likely because AncestorTreeDuplicator should have caught this
        #   and recreated it and updated the folder map, unless dest_parent is the destination root,
        #   which would mean something really weird is going on and we should let the client error bubble up.
        # Still, there may be other failure modes we haven't thought of so we don't want to fail the job.
        # So we log and persist the error and keep going.
        begin
          operation.log(:info, "Moving file to final destination.", file_id: file_id, dest_parent_id: dest_parent_id)
          main_wrapper.update_file(file_id, add_parents: dest_parent_id,
            remove_parents: request.temp_drive_id, supports_all_drives: true)
        rescue Google::Apis::ClientError => error
          handle_file_error(migration_file, error, "client_error_moving_to_destination", report: true, should_increment: should_increment)
          return
        end

        # This will also save the migration_file if it was an unpersisted one.
        migration_file.update!(status: "transferred")

        request.increment!(:ingest_progress) if should_increment
      end

      # Builds, but does not save, a migration file record based on the given ID.
      # We then proceed through ingestion with this unpersisted object, only saving it if
      # ingestion is successful. Returns nil if getting the file fails or if it's a folder.
      def build_new_migration_file(file_id)
        operation.log(:info, "No matching File record for file. Attempting to create.", file_id: file_id)

        gdrive_file = main_wrapper.get_file(file_id,
          fields: "name,parents,mimeType,webViewLink,iconLink,modifiedTime,owners(emailAddress),capabilities(canEdit)")

        if gdrive_file.parents.blank?
          operation.log(:error, "File has no accessible parents", file_id: file_id)
          return nil
        elsif gdrive_file.mime_type == GDrive::FOLDER_MIME_TYPE
          # This shouldn't normally happen since we don't allow picking folders in the picker
          # but just in case.
          operation.log(:error, "File is a folder, skipping", file_id: file_id)
          return nil
        end

        operation.files.build(
          external_id: file_id,
          name: gdrive_file.name,
          parent_id: gdrive_file.parents[0],
          mime_type: gdrive_file.mime_type,
          owner: gdrive_file.owners[0].email_address,
          status: "pending",
          icon_link: gdrive_file.icon_link,
          web_view_link: gdrive_file.web_view_link,
          modified_at: gdrive_file.modified_time
        )
      rescue Google::Apis::ClientError => error
        operation.log(:error, "Client error looking up file", file_id: file_id, message: error.to_s)
        nil
      end

      def handle_file_error(migration_file, error, error_type, should_increment:, report: false)
        request.increment!(:ingest_progress) if should_increment
        request.increment!(:error_count)

        operation.log(:error, "Encountered #{error_type}",
          file_id: migration_file.external_id,
          message: error.to_s,
          request_id: request.id)

        # No need to set an error on an unpersisted File, b/c those ones are from files the user
        # picked but we don't have records of, so we are just trying them but they may not be valid.
        if migration_file.persisted?
          migration_file.set_error(type: error_type, message: error.to_s)
        end

        if report
          Gather::ErrorReporter.instance.report(error, data: {
            type: error_type,
            operation_id: operation.id,
            request_id: request.id,
            file_id: migration_file.external_id
          })
        end

        if request.error_count >= MAX_ERRORS
          operation.log(:error, "GDrive max ingest errors reached", count: MAX_ERRORS,
            request_id: request.id)
          Gather::ErrorReporter.instance.report(StandardError.new("GDrive max ingest errors reached"), data: {
            count: MAX_ERRORS,
            operation_id: operation.id,
            request_id: request.id
          })
          request.set_ingest_failed
          raise IngestFailedError
        end
      end
    end
  end
end
