# frozen_string_literal: true

module Billing
  class TemplateMemberType < ApplicationRecord
    acts_as_tenant :cluster

    belongs_to :template, inverse_of: :template_member_types
    belongs_to :member_type, class_name: "People::MemberType", inverse_of: :billing_template_member_types
  end
end
