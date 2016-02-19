class TransactionPolicy < ApplicationPolicy
  include Accountish

  alias_method :transaction, :record

  def index?
    true
  end

  def show?
    false # Not used presently
  end

  def create?
    admin_or_biller?
  end

  def permitted_attributes
    [:incurred_on, :code, :description, :amount]
  end
end