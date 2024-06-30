# frozen_string_literal: true

# Enqueues the given list of jobs. Jobs must accept no arguments to be enqueued in this way.
namespace :jobs do
  # Rake doesn't allow variable command line args, so take the first 100!
  task :enqueue, (1..100).to_a.map(&:to_s) => :environment do |_t, args|
    args.to_a.each do |class_name|
      class_name.constantize.perform_later
    end
  end
end
