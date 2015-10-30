class LineItem < ActiveRecord::Base
  belongs_to :household
  belongs_to :invoice

  scope :incurred_between, ->(a,b){ where("incurred_on >= ? AND incurred_on <= ?", a, b) }
  scope :uninvoiced, ->{ where(invoice_id: nil) }
  scope :credit, ->{ where("amount < 0") }
  scope :charge, ->{ where("amount > 0") }

  after_create do
    household.account.line_item_added!(self)
  end

  after_destroy do
    household.account.recalculate! if invoice_id.nil?
  end

  validate :nonzero

  def charge?
    amount > 0
  end

  def abs_amount
    amount.abs
  end

  private

  def nonzero
    errors.add(:amount, "can't be zero") if amount.abs < 0.01
  end
end
