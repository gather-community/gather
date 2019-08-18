# frozen_string_literal: true

require File.expand_path(File.join(File.dirname(__FILE__), "../../spec/support/defaults"))

# TODO: This file duplicates a lot with the new_cluster script. Should unify them at some point.
# Creates a new cluster, community, and fake data. Also adds a superadmin user with the Gmail address
# given in Settings.admin_google_id (from settings.local.yml.example)
namespace :fake do
  task data: :environment do
    exit("admin_google_id setting not found") unless Settings.admin_google_id

    cluster = Cluster.create!(name: "Foo Cohousing")
    ActsAsTenant.current_tenant = cluster
    community = Community.create!(name: "Foo Cohousing", slug: "foo", abbrv: "fo")
    Utils::FakeData::MainGenerator.new(community: community, photos: !ENV.key?("NO_PHOTOS")).generate

    household = Household.create!(
      community: community,
      name: "Smith"
    )

    admin = User.create!(
      household: household,
      first_name: "Jane",
      last_name: "Smith",
      email: Settings.admin_google_id,
      google_email: Settings.admin_google_id,
      mobile_phone: "15555551212"
    )
    admin.add_role(:super_admin)
  end
end
