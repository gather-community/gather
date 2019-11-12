# frozen_string_literal: true

class RemoveSettingsFromCommunities < ActiveRecord::Migration[4.2]
  def change
    remove_column :communities, :settings, :text
  end
end
