# frozen_string_literal: true

module GDrive
  module Migration
    class Mailer < ApplicationMailer
      attr_reader :community

      def migration_request(migration_request)
        @migration_request = migration_request
        @operation = @migration_request.operation
        @community = @operation.community
        user = User.find_by(google_email: migration_request.google_email)
        @name = user ? "#{user.first_name} #{user.last_name}" : migration_request.google_email

        recipients = [user, migration_request.google_email].compact

        mail(
          to: recipients,
          reply_to: @operation.contact_email,
          subject: "[Action Required] Help #{@community.name} reorganize its Google Drive files!",
          include_inactive: :always
        )
      end
    end
  end
end
