# frozen_string_literal: true

# == Schema Information
#
# Table name: billing_templates
#
#  id           :bigint           not null, primary key
#  cluster_id   :bigint           not null
#  code         :string(16)       not null
#  community_id :bigint           not null
#  created_at   :datetime         not null
#  description  :string(255)      not null
#  updated_at   :datetime         not null
#  value        :decimal(10, 2)   not null
#
FactoryBot.define do
  factory :billing_template, class: "Billing::Template" do
    community { Defaults.community }
    description { "MyString" }
    code { "othchg" }
    value { "9.99" }
  end
end
