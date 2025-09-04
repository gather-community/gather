# frozen_string_literal: true

# == Schema Information
#
# Table name: users
#
#  id                     :integer          not null, primary key
#  allergies              :string
#  alternate_id           :string
#  birthdate              :date
#  calendar_token         :string
#  child                  :boolean          default(FALSE), not null
#  cluster_id             :integer          not null
#  confirmation_sent_at   :datetime
#  confirmation_token     :string
#  confirmed_at           :datetime
#  created_at             :datetime         not null
#  current_sign_in_at     :datetime
#  current_sign_in_ip     :inet
#  custom_data            :jsonb            not null
#  deactivated_at         :datetime
#  doctor                 :string
#  email                  :string(255)
#  encrypted_password     :string           default(""), not null
#  fake                   :boolean          default(FALSE), not null
#  first_name             :string           not null
#  full_access            :boolean          default(TRUE), not null
#  google_email           :string(255)
#  home_phone             :string
#  household_id           :integer          not null
#  job_choosing_proxy_id  :integer
#  joined_on              :date
#  last_name              :string           not null
#  last_sign_in_at        :datetime
#  last_sign_in_ip        :inet
#  medical                :text
#  mobile_phone           :string
#  paypal_email           :string(255)
#  preferred_contact      :string
#  privacy_settings       :jsonb            not null
#  pronouns               :string(24)
#  provider               :string
#  remember_created_at    :datetime
#  remember_token         :string
#  reset_password_sent_at :datetime
#  reset_password_token   :string
#  school                 :string
#  settings               :jsonb            not null
#  sign_in_count          :integer          default(0), not null
#  uid                    :string
#  unconfirmed_email      :string(255)
#  updated_at             :datetime         not null
#  work_phone             :string
#
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
    google_email { full_access ? "person#{rand(10_000_000..99_999_999)}@gmail.com" : nil }
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
      full_access { false }
      confirmed_at { nil } # Directory only users can't be confirmed.

      after(:build) do |child, evaluator|
        child.guardians = evaluator.guardians || [create(:user)]
      end
    end

    trait :full_access_child do
      transient do
        guardians { nil }
      end
      child { true }
      full_access { true }
      certify_13_or_older { "1" }

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
