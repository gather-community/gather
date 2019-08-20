# frozen_string_literal: true

# TODO: This file duplicates a lot with the fake_data script. Should unify them at some point.
namespace :db do
  ARGS = %i[cluster_name slug google_id first_name last_name sample_data].freeze
  task :new_cluster, ARGS => :environment do |_t, args|
    unless ARGS.all? { |k| args.send(k).present? }
      abort("Usage: rake db:new_cluster[<cluster_name>,<slug>,<admin google ID>,"\
        "<first_name>,<last_name>,<sample_data (y or n)>]")
    end
    ActiveRecord::Base.transaction do
      cluster = Cluster.create!(name: args.cluster_name)
      ActsAsTenant.with_tenant(cluster) do
        cmty = Community.create!(name: args.cluster_name, slug: args.slug)
        admin_hhold = Household.create!(
          community: cmty,
          name: args.last_name
        )
        admin = User.create!(
          first_name: args.first_name,
          last_name: args.last_name,
          google_email: args.google_id,
          email: args.google_id,
          household: admin_hhold
        )
        admin.add_role(:admin)
        sample_data = args.sample_data.casecmp("y").zero?
        Utils::FakeData::MainGenerator.new(community: cmty, sample_data: sample_data, photos: true).generate
      end
    end
  end
end
