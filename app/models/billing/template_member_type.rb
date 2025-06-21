# frozen_string_literal: true

# == Schema Information
#
# Table name: billing_template_member_types
#
#  id             :bigint           not null, primary key
#  cluster_id     :bigint           not null
#  created_at     :datetime         not null
#  member_type_id :bigint           not null
#  template_id    :bigint           not null
#  updated_at     :datetime         not null
#
module Billing
  class TemplateMemberType < ApplicationRecord
    acts_as_tenant :cluster

    belongs_to :template, inverse_of: :template_member_types
    belongs_to :member_type, class_name: "People::MemberType", inverse_of: :billing_template_member_types
  end
end
