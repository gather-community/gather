# frozen_string_literal: true

# Feature flags can now be created from the admin UI, so the name gets a length limit that the
# form and the input field also enforce.
class LimitFeatureFlagNameLength < ActiveRecord::Migration[8.1]
  def up
    change_column(:feature_flags, :name, :string, limit: 64, null: false)
  end

  def down
    change_column(:feature_flags, :name, :string, null: false)
  end
end
