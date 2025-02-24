# frozen_string_literal: true

# Deletes all sample data for the cluster with the given ID, except for non-fake users.
# See SampleDataRemover for full list of what is removed.
namespace :db do
  task :clear_sample_data, [:cluster_name] => :environment do
    if ENV["CLUSTER_NAME"].blank?
      raise %(Please specify cluster name, e.g. rake fake:clear_data CLUSTER_NAME="Funton Cohousing")
    end

    cluster = Cluster.find_by!(name: ENV.fetch("CLUSTER_NAME", nil))
    ActsAsTenant.current_tenant = cluster
    Utils::SampleDataRemover.new(cluster).remove
  end
end
