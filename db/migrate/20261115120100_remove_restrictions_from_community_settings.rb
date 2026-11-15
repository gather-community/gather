# frozen_string_literal: true

# Removes the unused `restrictions` group from community settings. Its field was defined in
# Community's settings spec but never read; it was removed along with that definition.
class RemoveRestrictionsFromCommunitySettings < ActiveRecord::Migration[8.1]
  def up
    execute("UPDATE communities SET settings = settings - 'restrictions' WHERE settings ? 'restrictions'")
  end

  def down
  end
end
