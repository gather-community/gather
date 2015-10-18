class Invoice < ActiveRecord::Base
  TERMS = 30 # days

  belongs_to :household
  has_many :line_items, dependent: :nullify

  after_create do
    household.change_balance!(total_due)
  end

  after_destroy do
    household.change_balance!(-total_due)
  end

  # Populates the invoice with
  def populate
    self.line_items = LineItem.where(invoice_id: nil).to_a
    self.due_on = Date.today + TERMS
    self.total_due = prev_balance + line_items.map(&:amount).sum
  end

  # Populates the invoice and saves only if there are any line items.
  # Returns whether the invoice was saved.
  def populate!
    populate
    line_items.any? && save!
  end
end
