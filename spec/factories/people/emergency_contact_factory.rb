FactoryBot.define do
  factory :emergency_contact, class: "People::EmergencyContact" do
    alt_phone { rand(3) > 1 ? Faker::PhoneNumber.simple : nil }
    email { rand(10) > 2 ? Faker::Internet.email : nil }
    location { Faker::Address.city }
    main_phone { Faker::PhoneNumber.simple }
    name { Faker::Name.name  }
    relationship { Faker::Relationship.relationship }
  end
end
