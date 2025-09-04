# frozen_string_literal: true

# == Schema Information
#
# Table name: group_mailman_lists
#
#  id                        :bigint           not null, primary key
#  additional_members        :jsonb
#  additional_senders        :jsonb
#  all_cmty_members_can_send :boolean          default(TRUE), not null
#  cluster_id                :bigint           not null
#  created_at                :datetime         not null
#  domain_id                 :bigint           not null
#  group_id                  :bigint           not null
#  last_synced_at            :datetime
#  managers_can_administer   :boolean          default(FALSE), not null
#  managers_can_moderate     :boolean          default(FALSE), not null
#  name                      :string           not null
#  remote_id                 :string
#  updated_at                :datetime         not null
#
FactoryBot.define do
  factory :group_mailman_list, class: "Groups::Mailman::List" do
    group
    sequence(:name) { |i| "list#{i}" }
    remote_id { nil }
    domain
  end
end
