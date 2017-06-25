FactoryGirl.define do
  factory :meals_message, class: "Meals::Message" do
    meal
    sender
    recipient_type { Meals::Message::RECIPIENT_TYPES.sample }
    body "Stuff"
  end
end
