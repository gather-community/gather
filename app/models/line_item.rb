class LineItem < ActiveRecord::Base
  belongs_to :account
  belongs_to :statement
  belongs_to :statementable, polymorphic: true

  scope :incurred_between, ->(a,b){ where("incurred_on >= ? AND incurred_on <= ?", a, b) }
  scope :no_statement, ->{ where(statement_id: nil) }
  scope :credit, ->{ where("amount < 0") }
  scope :charge, ->{ where("amount > 0") }

  before_save do
    if quantity.present? && unit_price.present?
      self.amount = quantity * unit_price
    end
  end

  after_create do
    account.line_item_added!(self)
  end

  after_destroy do
    account.recalculate! if statement_id.nil?
  end

  validate :nonzero
  validate :quantity_and_line_item

  def charge?
    amount > 0
  end

  def credit?
    amount < 0
  end

  def abs_amount
    amount.abs
  end

  private

  def nonzero
    errors.add(:amount, "can't be zero") if amount.abs < 0.01
  end

  def quantity_and_line_item
    if quantity.present? && unit_price.blank?
      errors.add(:unit_price, "can't be blank if quantity is present")
    elsif quantity.blank? && unit_price.present?
      errors.add(:quantity, "can't be blank if unit price is present")
    end
  end
end
