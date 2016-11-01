namespace :db do
  task fake_user_data: :environment do
    ActiveRecord::Base.transaction do
      community = Community.create!(
        name: "My Community",
        abbrv: "MC"
      )

      household = Household.create!(
        community: community,
        name: "Admins"
      )

      raise "admin_google_id setting not found" unless Rails.configuration.x.admin_google_id
      User.create!(
        household: household,
        first_name: "Alice",
        last_name: "Admin",
        email: Rails.configuration.x.admin_google_id,
        google_email: Rails.configuration.x.admin_google_id,
        mobile_phone: "17345551212",
        admin: true
      )

      Reservation::Resource.create!(
        community: community,
        name: "Dining Hall",
        meal_hostable: true
      )
    end
  end
end
