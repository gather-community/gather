# frozen_string_literal: true

namespace :elasticsearch do
  desc "Reindex Work::Shift (required after mapping change adding community_id/period_id)"
  task reindex_shifts: :environment do
    puts "Dropping and recreating Work::Shift index..."
    Work::Shift.__elasticsearch__.create_index!(force: true)
    puts "Importing all shifts..."
    ActsAsTenant.without_tenant { Work::Shift.import }
    puts "Done."
  end

  desc "Drop, recreate, and reimport Wiki::Page index (run after mapping or serializer changes)"
  task import_wiki_pages: :environment do
    puts "Dropping and recreating Wiki::Page index..."
    Wiki::Page.__elasticsearch__.create_index!(force: true)
    puts "Importing all wiki pages..."
    ActsAsTenant.without_tenant { Wiki::Page.import }
    puts "Done."
  end

  desc "Drop, recreate, and reimport Work::Shift index (run after mapping or serializer changes)"
  task import_work_shifts: :environment do
    puts "Dropping and recreating Work::Shift index..."
    Work::Shift.__elasticsearch__.create_index!(force: true)
    puts "Importing all work shifts..."
    ActsAsTenant.without_tenant { Work::Shift.import }
    puts "Done."
  end

  desc "Drop, recreate, and reimport Calendars::Event index (run after mapping or serializer changes)"
  task import_calendar_events: :environment do
    puts "Dropping and recreating Calendars::Event index..."
    Calendars::Event.__elasticsearch__.create_index!(force: true)
    puts "Importing all calendar events..."
    ActsAsTenant.without_tenant { Calendars::Event.includes(:calendar).import }
    puts "Done."
  end

  desc "Drop, recreate, and reimport Calendars::Calendar index (run after mapping or serializer changes)"
  task import_calendars: :environment do
    puts "Dropping and recreating Calendars::Calendar index..."
    Calendars::Calendar.__elasticsearch__.create_index!(force: true)
    puts "Importing all calendars..."
    ActsAsTenant.without_tenant { Calendars::Calendar.import }
    puts "Done."
  end

  desc "Drop, recreate, and reimport Groups::Group index (run after mapping or serializer changes)"
  task import_groups: :environment do
    puts "Dropping and recreating Groups::Group index..."
    Groups::Group.__elasticsearch__.create_index!(force: true)
    puts "Importing all groups..."
    ActsAsTenant.without_tenant { Groups::Group.includes(:communities, :mailman_list).import }
    puts "Done."
  end

  desc "Drop, recreate, and reimport User index (run after mapping or serializer changes)"
  task import_users: :environment do
    puts "Dropping and recreating User index..."
    User.__elasticsearch__.create_index!(force: true)
    puts "Importing all users..."
    ActsAsTenant.without_tenant { User.includes(:household).import }
    puts "Done."
  end

  desc "Drop, recreate, and reimport Household index (run after mapping or serializer changes)"
  task import_households: :environment do
    puts "Dropping and recreating Household index..."
    Household.__elasticsearch__.create_index!(force: true)
    puts "Importing all households..."
    ActsAsTenant.without_tenant { Household.import }
    puts "Done."
  end

  desc "Drop, recreate, and reimport Meals::Meal index (run after mapping or serializer changes)"
  task import_meals: :environment do
    puts "Dropping and recreating Meals::Meal index..."
    Meals::Meal.__elasticsearch__.create_index!(force: true)
    puts "Importing all meals..."
    ActsAsTenant.without_tenant { Meals::Meal.import }
    puts "Done."
  end

  desc "Drop, recreate, and reimport People::Memorial index (run after mapping or serializer changes)"
  task import_memorials: :environment do
    puts "Dropping and recreating People::Memorial index..."
    People::Memorial.__elasticsearch__.create_index!(force: true)
    puts "Importing all memorials..."
    ActsAsTenant.without_tenant { People::Memorial.includes(user: :household, messages: []).import }
    puts "Done."
  end

  desc "Drop, recreate, and reimport People::EmergencyContact index (run after mapping or serializer changes)"
  task import_emergency_contacts: :environment do
    puts "Dropping and recreating People::EmergencyContact index..."
    People::EmergencyContact.__elasticsearch__.create_index!(force: true)
    puts "Importing all emergency contacts..."
    ActsAsTenant.without_tenant { People::EmergencyContact.includes(:household).import }
    puts "Done."
  end

  desc "Drop, recreate, and reimport People::Pet index (run after mapping or serializer changes)"
  task import_pets: :environment do
    puts "Dropping and recreating People::Pet index..."
    People::Pet.__elasticsearch__.create_index!(force: true)
    puts "Importing all pets..."
    ActsAsTenant.without_tenant { People::Pet.includes(:household).import }
    puts "Done."
  end

  desc "Drop, recreate, and reimport People::Vehicle index (run after mapping or serializer changes)"
  task import_vehicles: :environment do
    puts "Dropping and recreating People::Vehicle index..."
    People::Vehicle.__elasticsearch__.create_index!(force: true)
    puts "Importing all vehicles..."
    ActsAsTenant.without_tenant { People::Vehicle.includes(:household).import }
    puts "Done."
  end

  desc "Drop, recreate, and reimport Billing::Transaction index (run after mapping or serializer changes)"
  task import_transactions: :environment do
    puts "Dropping and recreating Billing::Transaction index..."
    Billing::Transaction.__elasticsearch__.create_index!(force: true)
    puts "Importing all transactions..."
    ActsAsTenant.without_tenant { Billing::Transaction.includes(account: :community).import }
    puts "Done."
  end

  desc "Drop, recreate, and reimport all Elasticsearch indices"
  task import_all: %i[
    import_wiki_pages
    import_work_shifts
    import_calendar_events
    import_calendars
    import_groups
    import_users
    import_households
    import_meals
    import_memorials
    import_emergency_contacts
    import_pets
    import_vehicles
    import_transactions
  ]
end
