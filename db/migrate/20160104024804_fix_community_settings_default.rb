# frozen_string_literal: true

class FixCommunitySettingsDefault < ActiveRecord::Migration[4.2]
  def up
    change_column_default :communities, :settings, "--- {}\n"
  end

  def down
  end
end
