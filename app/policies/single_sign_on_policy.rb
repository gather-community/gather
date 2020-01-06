# frozen_string_literal: true

class SingleSignOnPolicy < ApplicationPolicy
  def sign_on?
    active?
  end
end
