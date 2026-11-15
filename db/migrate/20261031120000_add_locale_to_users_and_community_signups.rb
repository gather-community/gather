# frozen_string_literal: true

# The language Gather writes to a person in when their browser isn't involved: emails and calendar feeds.
# Every user has one. Existing users get English, which is what they've been getting; new users start with
# their community's default (see User#assign_default_locale). A signup's locale becomes the new community's
# default.
class AddLocaleToUsersAndCommunitySignups < ActiveRecord::Migration[8.1]
  def up
    add_column :users, :locale, :string, limit: 10
    execute("UPDATE users SET locale = 'en'")
    change_column_null :users, :locale, false
    add_column :community_signups, :locale, :string, limit: 10, null: false, default: "en"
  end

  def down
    remove_column :community_signups, :locale
    remove_column :users, :locale
  end
end
