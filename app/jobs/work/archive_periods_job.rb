# frozen_string_literal: true

module Work
  # Archives periods that ended more than Work::Period::AUTO_ARCHIVE_AGE ago.
  class ArchivePeriodsJob < ApplicationJob
    def perform
      ActsAsTenant.without_tenant do
        Period.auto_archivable.find_each { |period| archive_period(period) }
      end
    end

    private

    def archive_period(period)
      # We have to set the tenant in case associated records get changed by listeners.
      ActsAsTenant.with_tenant(period.cluster) do
        period.archive_if_appropriate
      end
    end
  end
end
