# frozen_string_literal: true

class HouseholdSerializer < ApplicationSerializer
  attributes :id, :name, :name_with_prefix
  delegate :name_with_prefix, to: :decorated
end
