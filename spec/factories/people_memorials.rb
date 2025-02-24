FactoryBot.define do
  factory :people_memorial, class: "People::Memorial" do
    user { nil }
    birth_year { 1 }
    death_year { 1 }
  end
end
