# frozen_string_literal: true

class RemoveCommunityAbbreviationUniqueness < ActiveRecord::Migration[4.2]
  def change
    remove_index :communities, :abbrv
  end
end
