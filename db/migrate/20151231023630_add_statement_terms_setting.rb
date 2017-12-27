class AddStatementTermsSetting < ActiveRecord::Migration[4.2]
  def up
    c = Community.find_by!(name: "Touchstone")
    c.settings[:statement_terms] = 30
    c.save!
  end
end
