# frozen_string_literal: true

FactoryBot.define do
  factory :memorial, class: "People::Memorial" do
    birth_year { 1950 }
    death_year { 2015 }
    user
  end
end
