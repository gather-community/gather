# frozen_string_literal: true

namespace :search do
  desc "Recreate the work shift search index and index every shift, e.g. after changing its analysis settings"
  task reindex: :environment do
    puts "Indexed #{Work::ShiftIndexUpdater.instance.rebuild_index} shifts"
  end
end
