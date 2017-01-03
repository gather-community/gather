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

      raise "admin_google_id setting not found" unless Settings.admin_google_id
      admin = User.create!(
        household: household,
        first_name: "Alice",
        last_name: "Admin",
        email: Settings.admin_google_id,
        google_email: Settings.admin_google_id,
        mobile_phone: "17345551212"
      )
      admin.add_role(:super_admin)

      Reservation::Resource.create!(
        community: community,
        name: "Dining Hall",
        meal_hostable: true
      )
    end
  end
end
