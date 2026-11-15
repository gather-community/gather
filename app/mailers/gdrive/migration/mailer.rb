# frozen_string_literal: true

module GDrive
  module Migration
    class Mailer < ApplicationMailer
      def migration_request(migration_request)
        @migration_request = migration_request
        @operation = @migration_request.operation
        @community = @operation.community
        user = User.find_by(google_email: migration_request.google_email)
        @name = user ? "#{user.first_name} #{user.last_name}" : migration_request.google_email

        recipients = [user, migration_request.google_email].compact

        # The Google account may not belong to anyone in Gather, so fall back to the community's language.
        locale = user ? Gather::Locales.for_user(user) : Gather::Locales.for_community(@community)
        in_locale_of(locale: locale) do
          mail(
            to: recipients,
            reply_to: @operation.contact_email,
            subject: t("gdrive.migration.request_subject", community: @community.name)
          )
        end
      end
    end
  end
end
