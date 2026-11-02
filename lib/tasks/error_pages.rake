# frozen_string_literal: true

namespace :error_pages do
  desc "Regenerate the static error pages in public/ from app/views/error_pages, for each released locale"
  task generate: :environment do
    Gather::ErrorPages.write_all
    puts "Wrote #{Gather::ErrorPages.files.keys.join(", ")}"
  end
end
