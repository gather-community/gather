# frozen_string_literal: true

FactoryBot.define do
  FactoryBot::DEFAULT_PASSWORD = "ga4893d4bXq;"

  factory :user do
    transient do
      community { nil }
      photo_path { Rails.root.join("spec", "fixtures", "cooper.jpg") }
    end

    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }
    email { "person#{rand(10_000_000..99_999_999)}@example.com" }
    google_email { "person#{rand(10_000_000..99_999_999)}@gmail.com" }
    mobile_phone { "5555551212" }
    password { FactoryBot::DEFAULT_PASSWORD }
    password_confirmation { FactoryBot::DEFAULT_PASSWORD }
    confirmed_at { Time.current - 60 }
    confirmation_sent_at { nil }

    household do
      attribs = {member_count: 0} # Don't want to create extra users.
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

    trait :active do
      # active is default
    end

    trait :inactive do
      deactivated_at { Time.current - 1 }

      after(:build) do |user|
        user.household.deactivated_at = Time.current - 1
      end
    end

    trait :adult do
      # adult is default
    end

    trait :child do
      transient do
        guardians { nil }
      end
      child { true }
      confirmed_at { nil } # Children can't be confirmed.

      after(:build) do |child, evaluator|
        child.guardians = evaluator.guardians || [create(:user)]
      end
    end

    trait :with_photo do
      after(:build) do |user, evaluator|
        user.photo.attach(io: File.open(evaluator.photo_path), filename: File.basename(evaluator.photo_path))
      end
    end

    trait :unconfirmed do
      confirmed_at { nil }
    end

    trait :pending_reconfirmation do
      unconfirmed_email { "newemail@example.com" }
    end

    trait :with_random_password do
      password { People::PasswordGenerator.instance.generate }
      password_confirmation { password }
    end
  end
end
