# frozen_string_literal: true

module GDrive
  module Migration
    # Creates and emails out consent requests.
    class ConsentRequestJob < ApplicationJob
      def perform(cluster_id:, operation_id:, google_emails:)
        ActsAsTenant.with_tenant(Cluster.find(cluster_id)) do
          operation = Operation.find(operation_id)
          operation.log(:info, "ConsentRequestJob starting", cluster_id: cluster_id)
          google_emails.each do |google_email|
            file_count = File.owned_by(google_email).count
            consent_request = ConsentRequest.create!(
              file_count: file_count,
              google_email: google_email,
              operation_id: operation_id
            )
            Mailer.consent_request(consent_request).deliver_now
          end
        end
      end
    end
  end
end
