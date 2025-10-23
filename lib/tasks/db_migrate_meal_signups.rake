# frozen_string_literal: true

namespace :db do
  task migrate_meals: :environment do
    # do we migrate all tenants at once? What is the procedure for this?
    CH.tenant(1)
    parts = Meals::SignupPart.all
    parts.each do |p|
      p.user_id = p.signup.household.users.first.id
      p.save!
    end
  end
end
