# frozen_string_literal: true

class SubscriptionPolicy < ApplicationPolicy
  alias subscription record

  def show?
    active_admin?
  end

  def start_payment?
    active_admin?
  end

  def payment?
    active_admin?
  end
end
