# frozen_string_literal: true

module Utils
  # Totals across all communities for the operator communities page's Stats sidebar.
  # Users are counted if they're active and not fake (sample data).
  class CommunityStats
    # The date of Gather's first commit.
    FIRST_COMMIT_DATE = Date.new(2015, 7, 14)

    # communities should have status loadable cheaply (see CommunitySummarizer#with_status).
    def initialize(communities:)
      @communities = communities
    end

    def status_count(status)
      status_counts[status] || 0
    end

    # Active adults in subscribed communities.
    def paying_users
      subscribed_ids = communities.select { |c| c.status == :subscribed }.map(&:id)
      count { users.adults.in_community(subscribed_ids) }
    end

    def adults
      count { users.adults }
    end

    def children
      count { users.where(child: true) }
    end

    # Counts the first commit's year and the current year, so 2015 through 2026 is 12.
    def years_active
      Time.zone.today.year - FIRST_COMMIT_DATE.year + 1
    end

    private

    attr_reader :communities

    def status_counts
      @status_counts ||= communities.map(&:status).tally
    end

    # Limited to the given communities, so the totals match what the page lists.
    def users
      User.active.real.in_community(communities.map(&:id))
    end

    def count(&block)
      ActsAsTenant.without_tenant { block.call.count }
    end
  end
end
