# frozen_string_literal: true

# == Schema Information
#
# Table name: messaging_accounts
#
#  id           :bigint           not null, primary key
#  cluster_id   :bigint           not null
#  community_id :bigint           not null
#  currency     :string(3)        not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
FactoryBot.define do
  factory :messaging_account, class: "Messaging::Account" do
    community { Defaults.community }
    currency { "usd" }
  end
end
