FactoryBot.define do
  factory :meal_message, class: "Meals::Message" do
    meal
    association :sender, factory: :user
    recipient_type { Meals::Message::RECIPIENT_TYPES.sample.to_s }
    body { "Stuff" }
  end
end
