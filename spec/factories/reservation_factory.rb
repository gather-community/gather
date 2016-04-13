FactoryGirl.define do
  factory :reservation, class: "Reservation::Reservation" do
    name "Fun times"
    resource
    association :reserver, factory: :user
    sequence(:starts_at) { |n| Time.now.tomorrow.midnight + n.hours }
    sequence(:ends_at) { |n| Time.now.tomorrow.midnight + (n + 1).hours }
    kind nil
  end
end
