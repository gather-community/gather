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

  desc "Backfill Wiki::Page index (run once after deploy; index is created by initializer)"
  task import_wiki_pages: :environment do
    puts "Importing all wiki pages..."
    ActsAsTenant.without_tenant { Wiki::Page.import }
    puts "Done."
  end
end
