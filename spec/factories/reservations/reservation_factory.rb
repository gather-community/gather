# frozen_string_literal: true

FactoryBot.define do
  factory :reservation, class: "Reservations::Reservation" do
    name "Fun times"
    resource
    association :reserver, factory: :user
    sequence(:starts_at) { |n| Time.current.tomorrow.midnight + n.hours }
    sequence(:ends_at) { starts_at + 55.minutes }
    kind nil
  end
end
