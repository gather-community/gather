# frozen_string_literal: true

module Utils
  module Generators
    # Generates an admin user and invites to sign in.
    class AdminGenerator < Generator
      include ActiveModel::Model

      attr_accessor :community, :cluster, :admin, :email, :first_name, :last_name, :super_admin

      def generate
        admin = nil
        ActsAsTenant.with_tenant(cluster) do
          ActiveRecord::Base.transaction do
            self.community = cluster.communities[0]
            in_community_timezone { admin = generate_admin }
          end
        end
        admin
      end

      private

      def generate_admin
        household = Household.create!(community: community, name: last_name)
        self.admin = User.new(email: email, first_name: first_name, last_name: last_name,
                              household: household, dont_require_phone: true)
        super_admin ? admin.skip_confirmation! : admin.skip_confirmation_notification!
        add_password if super_admin
        admin.save!
        admin.add_role(super_admin ? :super_admin : :admin)
        invite unless super_admin
        admin
      end

      def add_password
        admin.password = admin.password_confirmation = People::PasswordGenerator.instance.generate
      end

      def invite
        People::SignInInvitationJob.perform_now(community.id, [admin.id])
      end
    end
  end
end
