# frozen_string_literal: true

class RemoveSlugFromGroups < ActiveRecord::Migration[6.0]
  def change
    remove_column :groups, :slug, :string
  end
end
