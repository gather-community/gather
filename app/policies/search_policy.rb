# frozen_string_literal: true

class SearchPolicy < ApplicationPolicy
  def index?
    active?
  end
end
