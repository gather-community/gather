# frozen_string_literal: true

FactoryBot.define do
  factory :reservation_protocoling, class: "Reservations::Protocoling" do
    resource
    protocol
  end
end
