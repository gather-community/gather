# frozen_string_literal: true

module GDrive
  module Migration
    # Creates and emails out migration requests.
    class RequestJob < ApplicationJob
      attr_accessor :operation

      def perform(cluster_id:, operation_id:, google_emails:)
        ActsAsTenant.with_tenant(Cluster.find(cluster_id)) do
          self.operation = Operation.find(operation_id)
          operation.log(:info, "RequestJob starting", cluster_id: cluster_id)
          google_emails.each do |google_email|
            create_and_send_request(google_email)
          end
        end
      end

      private

      # This is a separate class method so we can stub it in tests.
      def self.random_drive_id
        SecureRandom.hex(6)
      end

      def create_and_send_request(google_email)
        if Request.where(google_email: google_email, operation_id: operation.id).exists?
          operation.log(:info, "Request already exists, not creating or sending email",
            google_email: google_email)
        else
          file_count = File.owned_by(google_email).count
          request = Request.create!(
            file_count: file_count,
            google_email: google_email,
            operation_id: operation.id
          )
          operation.log(:info, "Created migration request", google_email: google_email, request_id: request.id)
          create_file_drop_drive(request)
          Mailer.migration_request(request).deliver_now
        end
      end

      def create_file_drop_drive(request)
        random_id = self.class.random_drive_id
        drive_name = "Gather File Drop #{random_id}"
        file_drop_drive = Google::Apis::DriveV3::Drive.new(name: drive_name)
        operation.log(:info, "Creating file drop drive", name: file_drop_drive.name)

        # This could only fail if our permissons are bad, which means the whole operation is broken.
        # So we let it bubble up and stop the job.
        file_drop_drive = wrapper.create_drive(random_id, file_drop_drive)

        # This could only fail if our permissons are bad, which means the whole operation is broken.
        # So we let it bubble up and stop the job.
        operation.log(:info, "Adding temp drive write permission", requestee: request.google_email)
        permission = Google::Apis::DriveV3::Permission.new(type: "user", email_address: request.google_email, role: "writer")
        wrapper.create_permission(file_drop_drive.id, permission, supports_all_drives: true, send_notification_email: true)

        operation.log(:info, "Saving file drop drive ID", drive_id: file_drop_drive.id)
        request.update!(file_drop_drive_id: file_drop_drive.id, file_drop_drive_name: drive_name)
      end

      def wrapper
        return @wrapper if @wrapper

        # We build the wrapper using the main config because we are creating
        # file drop drives in the community Workspace account.
        config = Config.find_by(community: operation.community)
        @wrapper = Wrapper.new(config: config, google_user_id: config.org_user_id)
      end
    end
  end
end
