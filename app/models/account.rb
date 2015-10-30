class Account < ActiveRecord::Base
  belongs_to :household, inverse_of: :account

  delegate :name, to: :household, prefix: true

  # Updates account for latest invoice. Assumes invoice is latest one since the UI enforces this.
  def invoice_added!(invoice)
    self.last_invoiced_on = invoice.created_on
    self.due_last_invoice = invoice.total_due
    self.total_new_credits = 0
    self.total_new_charges = 0
    save!
  end

  def line_item_added!(line_item)
    if line_item.charge?
      self.total_new_charges += line_item.amount
    else
      self.total_new_credits += line_item.abs_amount
    end
    save!
  end

  def recalculate!
    new_amounts = LineItem.select("
      SUM(CASE WHEN amount < 0 THEN amount ELSE 0 END) AS new_credits,
      SUM(CASE WHEN amount > 0 THEN amount ELSE 0 END) AS new_charges").
      where(household_id: household_id).
      where(invoice_id: nil).to_a.first

    last_invoice = Invoice.order(:created_at).last

    self.last_invoiced_on = last_invoice.try(:created_on)
    self.due_last_invoice = last_invoice.try(:total_due)
    self.total_new_credits = new_amounts.try(:[], "new_credits").try(:abs) || 0
    self.total_new_charges = new_amounts.try(:[], "new_charges") || 0
    save!
  end

  def outstanding_balance
    (due_last_invoice || 0) - total_new_credits
  end

  def current_balance
    outstanding_balance + total_new_charges
  end

  def last_invoice
    @last_invoice ||= household.invoices.order(:created_at).last
  end
end