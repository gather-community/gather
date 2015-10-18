class Invoice < ActiveRecord::Base
  TERMS = 30 # days

  belongs_to :household
  has_many :line_items, dependent: :nullify

  # Populates the invoice with
  def populate
    self.line_items = LineItem.incurred_between(started_on, ended_on).to_a
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
