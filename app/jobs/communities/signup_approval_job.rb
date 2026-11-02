# frozen_string_literal: true

module Communities
  class SignupApprovalJob < ApplicationJob
    def perform(signup_id)
      signup = Communities::Signup.find(signup_id)

      cluster = Utils::Generators::MainGenerator.new(
        cmty_name: signup.community_name,
        country_code: signup.country_code,
        slug: signup.slug,
        sample_data: signup.want_sample_data,
        photos: true
      ).generate

      ActsAsTenant.with_tenant(cluster) do
        community = cluster.communities.first
        community.settings.time_zone = signup.time_zone
        community.settings.locale = signup.locale
        community.save!
        # Sample members were generated before the community had its language, so they start in it now.
        # The admin, created below, starts in it by default.
        User.in_community(community).update_all(locale: signup.locale)
      end

      Utils::Generators::AdminGenerator.new(
        cluster: cluster,
        email: signup.contact_email,
        first_name: signup.contact_first_name,
        last_name: signup.contact_last_name,
        super_admin: false
      ).generate

      signup.mark_created!
      Communities::SignupMailer.application_approved(signup).deliver_now
      Communities::SignupMailer.approval_created(signup).deliver_now
    rescue => e
      signup&.mark_failed!(message: e.message)
      Communities::SignupMailer.approval_failed(signup).deliver_now if signup
      raise
    end
  end
end
