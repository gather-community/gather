class ReimbursementRequest
  include ActiveModel::Validations
  include ActiveRecord::AttributeAssignment

  PAYMENT_METHODS = %w(check credit)

  attr_accessor :ingredient_cost, :pantry_cost, :payment_method

  validates :ingredient_cost, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :pantry_cost, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :payment_method, presence: true

  def persisted?
    false
  end
end
