# frozen_string_literal: true

# == Schema Information
#
# Table name: meal_messages
#
#  id             :integer          not null, primary key
#  body           :text             not null
#  cluster_id     :integer          not null
#  created_at     :datetime         not null
#  kind           :string           default("normal"), not null
#  meal_id        :integer          not null
#  recipient_type :string           not null
#  sender_id      :integer          not null
#  updated_at     :datetime         not null
#
FactoryBot.define do
  factory :meal_message, class: "Meals::Message" do
    meal
    association :sender, factory: :user
    recipient_type { Meals::Message::RECIPIENT_TYPES.sample.to_s }
    body { "Stuff" }
  end
end
