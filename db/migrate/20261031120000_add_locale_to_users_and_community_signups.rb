# frozen_string_literal: true

# The language Gather writes to a person in when their browser isn't involved: emails and calendar feeds.
# Nil on a user means "use the community's default", so people who never chose follow any later change to it.
# A signup's locale becomes the new community's default.
class AddLocaleToUsersAndCommunitySignups < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :locale, :string, limit: 10
    add_column :community_signups, :locale, :string, limit: 10, null: false, default: "en"
  end
end
