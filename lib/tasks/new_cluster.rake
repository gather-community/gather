namespace :db do
  task :new_cluster, [:cluster_name, :admin_google_acct] => :environment do |t, args|
    unless args.cluster_name.present? && args.admin_google_acct.present?
      raise "Usage: rake db:new_cluster[<cluster_name>, <admin google account>]"
    end
    ActiveRecord::Base.transaction do
      cluster = Cluster.create!(name: args.cluster_name)
      ActsAsTenant.with_tenant(cluster) do
        cmty = Community.create!(name: args.cluster_name, slug: args.cluster_name.downcase.gsub(/[^a-z]/, ""))
        Utils::FakeData::MainGenerator.new(community: cmty, photos: true).generate
      end
    end
  end
end
