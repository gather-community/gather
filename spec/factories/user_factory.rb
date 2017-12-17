FactoryBot.define do
  factory :user do
    transient do
      community nil
    end

    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }
    email { "person#{rand(1000000..9999999)}@example.com" }
    google_email { "person#{rand(1000000..9999999)}@gmail.com" }
    mobile_phone "5555551212"

    household do
      attribs = {with_members: false} # Don't want to create extra users.
      attribs[:community] = community if community
      build(:household, attribs)
    end

    %i(admin cluster_admin super_admin biller photographer meals_coordinator).each do |role|
      factory role do
        after(:create) do |user|
          user.add_role(role)
        end
      end
    end

    trait :inactive do
      deactivated_at { Time.current - 1 }
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
  end
end
