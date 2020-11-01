# frozen_string_literal: true

module Billing
  class Template < ApplicationRecord
    acts_as_tenant :cluster

    belongs_to :community, inverse_of: :billing_templates
  end
end
