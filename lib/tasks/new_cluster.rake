namespace :db do
  ARGS = [:cluster_name, :slug, :google_id, :first_name, :last_name]
  task :new_cluster, ARGS => :environment do |t, args|
    unless ARGS.all? { |k| args.send(k).present? }
      abort("Usage: rake db:new_cluster[<cluster_name>,<slug>,<admin google ID>,<first_name>,<last_name>]")
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
          household: admin_hhold,
          mobile_phone: "5555551212"
        )
        admin.add_role(:admin)
        Utils::FakeData::MainGenerator.new(community: cmty, photos: true).generate
      end
    end
  end
end
