FactoryGirl.define do
  factory :meals_message, class: "Meals::Message" do
    meal
    association :sender, factory: :user
    recipient_type { Meals::Message::RECIPIENT_TYPES.sample }
    body "Stuff"
  end
end
