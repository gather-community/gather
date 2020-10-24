# frozen_string_literal: true

FactoryBot.define do
  factory :member_type, class: "People::MemberType" do
    community
    sequence(:name) { |n| "Member Type #{n}" }
  end
end
