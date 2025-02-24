# frozen_string_literal: true

# == Schema Information
#
# Table name: billing_template_member_types
#
#  id             :bigint           not null, primary key
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  cluster_id     :bigint           not null
#  member_type_id :bigint           not null
#  template_id    :bigint           not null
#
# Indexes
#
#  index_billing_template_member_types_on_cluster_id      (cluster_id)
#  index_billing_template_member_types_on_member_type_id  (member_type_id)
#  index_billing_template_member_types_on_template_id     (template_id)
#
# Foreign Keys
#
#  fk_rails_...  (cluster_id => clusters.id)
#  fk_rails_...  (member_type_id => people_member_types.id)
#  fk_rails_...  (template_id => billing_templates.id)
#
module Billing
  class TemplateMemberType < ApplicationRecord
    acts_as_tenant :cluster

    belongs_to :template, inverse_of: :template_member_types
    belongs_to :member_type, class_name: "People::MemberType", inverse_of: :billing_template_member_types
  end
end
