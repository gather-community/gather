# frozen_string_literal: true

# == Schema Information
#
# Table name: meal_signups
#
#  id           :integer          not null, primary key
#  cluster_id   :integer          not null
#  comments     :text
#  created_at   :datetime         not null
#  household_id :integer          not null
#  meal_id      :integer          not null
#  notified     :boolean          default(FALSE), not null
#  takeout      :boolean          default(FALSE), not null
#  updated_at   :datetime         not null
#
FactoryBot.define do
  factory :meal_signup, class: "Meals::Signup" do
    transient do
      # Array of integers defining multiple diner counts.
      diner_counts { nil }
    end

    household
    meal

    after(:build) do |signup, evaluator|
      # Create types and parts for the given share values.
      (evaluator.diner_counts || []).each_with_index do |count, index|
        break if index >= signup.types.size
        next if count.zero?
        signup.parts.build(count: count, type: signup.types[index])
      end
    end
  end
end
