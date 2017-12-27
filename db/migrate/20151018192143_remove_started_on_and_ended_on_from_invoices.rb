class RemoveStartedOnAndEndedOnFromInvoices < ActiveRecord::Migration[4.2]
  def change
    remove_column :invoices, :started_on, :date
    remove_column :invoices, :ended_on, :date
  end
end
