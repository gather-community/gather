# frozen_string_literal: true

# == Schema Information
#
# Table name: group_mailman_users
#
#  id         :bigint           not null, primary key
#  cluster_id :bigint           not null
#  created_at :datetime         not null
#  remote_id  :string           not null
#  updated_at :datetime         not null
#  user_id    :bigint           not null
#
FactoryBot.define do
  factory :group_mailman_user, class: "Groups::Mailman::User" do
    user
    sequence(:remote_id) { |i| "abcd#{i}" }
  end
end
