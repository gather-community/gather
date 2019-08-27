# Deletes all data for the cluster with the given ID, except for non-fake user marked.
namespace :db do
  task :clear_sample_data, [:cluster_id] => :environment do |t, args|
    raise "Please specify cluster ID, e.g. rake fake:clear_data[123]" unless args.cluster_id.present?
    ActsAsTenant.current_tenant = Cluster.find(args.cluster_id)
    Utils::DataRemover.new(args.cluster_id.to_i).remove
  end
end
