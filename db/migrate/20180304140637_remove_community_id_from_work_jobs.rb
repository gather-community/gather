class RemoveCommunityIdFromWorkJobs < ActiveRecord::Migration[5.1]
  def up
    remove_column :work_jobs, :community_id
  end
end
