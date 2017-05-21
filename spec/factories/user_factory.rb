FactoryGirl.define do
  factory :user do
    transient do
      community nil
    end

    first_name "John"
    last_name "Doe"
    sequence(:email) { |n| "person#{n}@example.com" }
    sequence(:google_email) { |n| "person#{n}@gmail.com" }
    mobile_phone "5555551212"

    household do
      attribs = {with_members: false} # Don't want to create extra users.
      attribs[:community] = community if community
      build(:household, attribs)
    end

    %i(admin cluster_admin super_admin biller photographer).each do |role|
      factory role do
        after(:create) do |user|
          user.add_role(role)
        end
      end
    end

    trait :inactive do
      deactivated_at { Time.now - 1 }
    end

    trait :child do
      transient do
        no_guardians false
      end
      child true

      after(:build) do |child, evaluator|
        child.guardians = [create(:user)] unless evaluator.no_guardians
      end
    end

    trait :with_photo do
      photo { File.open("#{Rails.root}/spec/fixtures/cooper.jpg") }
    end
  end
end
