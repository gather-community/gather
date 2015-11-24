class Transaction < ActiveRecord::Base
  TYPES = [
    OpenStruct.new(code: "meal", charge?: true),
    OpenStruct.new(code: "oldbal", charge?: true, credit?: true),
    OpenStruct.new(code: "payment", credit?: true, manual?: true),
    OpenStruct.new(code: "reimb", credit?: true, manual?: true),
    OpenStruct.new(code: "othcrd", credit?: true, manual?: true),
    OpenStruct.new(code: "late", charge?: true, manual?: false),
    OpenStruct.new(code: "othchg", charge?: true, manual?: true)
  ]
  TYPES_BY_CODE = TYPES.index_by(&:code)
  MANUALLY_ADDABLE_TYPES = TYPES.select(&:manual?)

  belongs_to :account
  belongs_to :statement
  belongs_to :statementable, polymorphic: true

  scope :for_household, ->(h){ joins(account: :household).where("households.id = ?", h.id) }
  scope :for_community_or_household,
    ->(c,h){ joins(account: :household).where("households.community_id = ? OR households.id = ?", c.id, h.id) }
  scope :incurred_between, ->(a,b){ where("incurred_on >= ? AND incurred_on <= ?", a, b) }
  scope :no_statement, ->{ where(statement_id: nil) }
  scope :credit, ->{ where("amount < 0") }
  scope :charge, ->{ where("amount > 0") }

  delegate :household_id, :household_full_name, :community_id, to: :account

  before_validation do
    # Respect qty and unit price
    if quantity.present? && unit_price.present?
      self.amount = quantity * unit_price
    end
    # Ensure correct sign for item type
    if amount.present? && code.present?
      self.amount = (type.credit? ? -1 : 1) * amount.to_f.abs
    end
  end

  after_create do
    account.transaction_added!(self)
  end

  after_destroy do
    account.recalculate! if statement_id.nil?
  end

  validates :incurred_on, presence: true
  validates :code, presence: true
  validates :description, presence: true
  validates :amount, presence: true
  validates :abs_amount, numericality: { minimum: 0 }, if: ->(a){ a.present? }
  validate :nonzero
  validate :quantity_and_unit_price

  def charge?
    amount > 0
  end

  def credit?
    amount < 0
  end

  def chg_crd
    charge? ? "charge" : "credit"
  end

  def abs_amount
    amount.try(:abs)
  end

  def type
    TYPES_BY_CODE[code]
  end

  private

  def nonzero
    errors.add(:amount, "can't be zero") if amount.present? && abs_amount < 0.01
  end

  def quantity_and_unit_price
    if quantity.present? && unit_price.blank?
      errors.add(:unit_price, "can't be blank if quantity is present")
    elsif quantity.blank? && unit_price.present?
      errors.add(:quantity, "can't be blank if unit price is present")
    end
  end
end
