class RenameGuidelineInclusionsColumn < ActiveRecord::Migration
  def change
    rename_column :reservation_guideline_inclusions,
      :reservation_shared_guideline_id,
      :shared_guidelines_id
  end
end
