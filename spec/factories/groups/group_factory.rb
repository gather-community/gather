# frozen_string_literal: true

# == Schema Information
#
# Table name: groups
#
#  id                         :bigint           not null, primary key
#  availability               :string(10)       default("closed"), not null
#  can_administer_email_lists :boolean          default(FALSE), not null
#  can_moderate_email_lists   :boolean          default(FALSE), not null
#  can_request_jobs           :boolean          default(FALSE), not null
#  cluster_id                 :integer          not null
#  created_at                 :datetime         not null
#  deactivated_at             :datetime
#  description                :string(255)
#  kind                       :string(32)       default("committee"), not null
#  name                       :string(64)       not null
#  updated_at                 :datetime         not null
#
FactoryBot.define do
  factory :group, class: "Groups::Group" do
    transient do
      joiners { [] }
      opt_outs { [] }
    end

    sequence(:name) { |n| "Group #{n}" }
    communities { [Defaults.community] }

    trait :inactive do
      deactivated_at { Time.current }
    end

    after(:build) do |group, evaluator|
      evaluator.joiners.each do |joiner|
        group.memberships.build(user: joiner, kind: "joiner")
      end
      evaluator.opt_outs.each do |opt_out|
        group.memberships.build(user: opt_out, kind: "opt_out")
      end
    end
  end
end
