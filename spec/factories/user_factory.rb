# frozen_string_literal: true

FactoryBot.define do
  FactoryBot::DEFAULT_PASSWORD = "ga4893d4bXq;"

  factory :user do
    transient do
      community nil
    end

    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }
    email { "person#{rand(10_000_000..99_999_999)}@example.com" }
    google_email { "person#{rand(10_000_000..99_999_999)}@gmail.com" }
    mobile_phone "5555551212"
    password FactoryBot::DEFAULT_PASSWORD
    password_confirmation FactoryBot::DEFAULT_PASSWORD
    confirmed_at { Time.current - 60 }
    confirmation_sent_at { nil }

    household do
      attribs = {with_members: false} # Don't want to create extra users.
      attribs[:community] = community if community
      build(:household, attribs)
    end

    User::ROLES.each do |role|
      factory role do
        after(:create) do |user|
          user.add_role(role)
        end
      end
    end

    trait :inactive do
      deactivated_at { Time.current - 1 }

      after(:build) do |user|
        user.household.deactivated_at = Time.current - 1
      end
    end

    trait :child do
      transient do
        guardians nil
      end
      child true

      after(:build) do |child, evaluator|
        child.guardians = evaluator.guardians || [create(:user)]
      end
    end

    trait :with_photo do
      photo { File.open("#{Rails.root}/spec/fixtures/cooper.jpg") }
    end

    trait :unconfirmed do
      confirmed_at { nil }
    end

    trait :pending_reconfirmation do
      unconfirmed_email { "newemail@example.com" }
    end
  end
end
