# frozen_string_literal: true

module GDrive
  module Migration
    # Runs nightly. Cleans up migration requests whose links have expired (see Request::EXPIRES_AFTER).
    #
    # Each request has a file drop drive in the community's Workspace that the requestee can write to.
    # Once the link expires, the requestee shouldn't keep that access. An empty drive is deleted. A drive
    # with files still in it isn't, because deleting it would delete those files. Instead the requestee's
    # access is removed and the drive is left for the community to sort out.
    #
    # The link itself stops working as soon as it's old enough (Request#expired?), whether or not this has
    # run. Requests that were already old when this job was added are cleaned up on its first run.
    class RequestExpiryJob < BaseJob
      def perform
        requests = ActsAsTenant.without_tenant { Request.due_to_expire.includes(:cluster).to_a }
        requests.each do |request|
          with_cluster(request.cluster) { expire(request) }
        rescue => error
          # Not marked expired, so it's tried again tomorrow. Its link has stopped working regardless.
          Gather::ErrorReporter.instance.report(error,
            data: {job: self.class.name, request_id: request.id, operation_id: request.operation_id})
        end
      end

      private

      def expire(request)
        operation = request.operation
        if request.file_drop_drive_id.present?
          config = Config.find_by(community_id: operation.community_id)
          raise "No Drive config for community #{operation.community_id}" if config.nil?
          wrapper = Wrapper.new(config: config, google_user_id: config.org_user_id)
          clean_up_drive(request, operation, wrapper)
        end
        request.update!(expired_at: Time.current)
      end

      def clean_up_drive(request, operation, wrapper)
        drive_id = request.file_drop_drive_id
        if drive_empty?(wrapper, drive_id)
          operation.log(:info, "Deleting file drop drive for expired request", drive_id: drive_id,
            requestee: request.google_email)
          wrapper.delete_drive(drive_id)
          request.update!(file_drop_drive_id: nil)
        else
          operation.log(:warn, "File drop drive for expired request still has files, so it was kept. " \
            "Removing the requestee's access", drive_id: drive_id, requestee: request.google_email)
          remove_requestee_access(request, wrapper)
        end
      rescue Google::Apis::ClientError => error
        raise unless error.message.match?(/notFound/)
        # Someone already deleted it.
        operation.log(:info, "File drop drive for expired request was already gone", drive_id: drive_id)
        request.update!(file_drop_drive_id: nil)
      end

      # Trashed files count too, since Google won't delete a drive with anything in its trash.
      def drive_empty?(wrapper, drive_id)
        wrapper.list_files(corpora: "drive", drive_id: drive_id, include_items_from_all_drives: true,
          supports_all_drives: true, page_size: 1, fields: "files(id)").files.blank?
      end

      def remove_requestee_access(request, wrapper)
        permissions = wrapper.list_permissions(request.file_drop_drive_id,
          fields: "permissions(id,emailAddress)", supports_all_drives: true).permissions || []
        permissions.select { |p| p.email_address&.downcase == request.google_email.downcase }.each do |p|
          wrapper.delete_permission(request.file_drop_drive_id, p.id, supports_all_drives: true)
        end
      end
    end
  end
end
