# Creates fake data for the cluster with the given ID.
# If no community ID is given, uses first community in cluster.
namespace :fake do
  task :community_data, [:cluster_id, :community_id] => :environment do |t, args|
    raise "Please specify cluster ID, e.g. rake fake:community_data[123]" unless args.cluster_id.present?
    ActsAsTenant.current_tenant = Cluster.find(args.cluster_id)
    community = args.community_id ? Community.find(args.community_id) : Community.first
    Utils::FakeData::MainGenerator.new(community, photos: !ENV.key?("NO_PHOTOS")).generate
  end
end
