class FixCommunitySettingsDefault < ActiveRecord::Migration
  def up
    change_column_default :communities, :settings, "--- {}\n"
  end

  def down
  end
end
