class RemoveCommunityAbbreviationUniqueness < ActiveRecord::Migration
  def change
    remove_index :communities, :abbrv
  end
end
