# frozen_string_literal: true

class AddRankToCalendars < ActiveRecord::Migration[6.0]
  def up
    add_column :calendar_nodes, :rank, :integer, index: true

    ActsAsTenant.without_tenant do
      Community.find_each do |community|
        sql = <<-SQL
          UPDATE calendar_nodes SET rank = sub.rownum
            FROM (
              SELECT id, row_number() OVER (ORDER BY name) AS rownum
              FROM calendar_nodes WHERE community_id = #{community.id}
            ) sub
            WHERE calendar_nodes.id = sub.id;
        SQL
        connection.execute(sql)
      end
    end

    change_column_null :calendar_nodes, :rank, false
  end

  def down
    remove_column :calendar_nodes, :rank
  end
end
