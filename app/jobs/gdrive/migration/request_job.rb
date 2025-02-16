# frozen_string_literal: true

module GDrive
  module Migration
    # Creates and emails out migration requests.
    class RequestJob < ApplicationJob
      def perform(cluster_id:, operation_id:, google_emails:)
        ActsAsTenant.with_tenant(Cluster.find(cluster_id)) do
          operation = Operation.find(operation_id)
          operation.log(:info, "RequestJob starting", cluster_id: cluster_id)
          google_emails.each do |google_email|
            file_count = File.owned_by(google_email).count
            request = Request.create!(
              file_count: file_count,
              google_email: google_email,
              operation_id: operation_id
            )
            Mailer.request(request).deliver_now
          end
        end
      end
    end
  end
end
