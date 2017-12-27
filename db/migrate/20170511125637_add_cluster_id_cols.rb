class AddClusterIdCols < ActiveRecord::Migration[4.2]
  TABLES = %w(accounts assignments formulas households invitations meals meals_costs
    people_emergency_contacts people_guardianships people_vehicles reservation_guideline_inclusions
    reservation_protocolings reservation_protocols reservation_resourcings reservation_shared_guidelines
    reservations resources signups statements transactions users users_roles)

  def up
    initial_cluster_id = Cluster.first.id
    TABLES.each do |t|
      add_reference t, :cluster, index: true, foreign_key: true
      execute("UPDATE #{t} SET cluster_id = #{initial_cluster_id}")
      change_column_null t, :cluster_id, false
    end
  end

  def down
    TABLES.each do |t|
      remove_column t, :cluster_id
    end
  end
end
