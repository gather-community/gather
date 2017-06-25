FactoryGirl.define do
  factory :meals_message, class: "Meals::Message" do
    meal
    sender
    recipients { Meals::Message::RECIPIENTS.sample }
    body "Stuff"
  end
end
