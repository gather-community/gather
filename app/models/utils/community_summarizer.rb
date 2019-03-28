# frozen_string_literal: true

module Utils
  # Executes a complex query to build a report of activity for all communities.
  class CommunitySummarizer
    def communities(scope)
      ActsAsTenant.without_tenant do
        scope
          .select("communities.*, user_stats.*, meal_stats.*, rsrv_stats.*, job_stats.*, txn_stats.*")
          .joins(user_join, meal_join, rsrv_join, job_join, txn_join)
          .by_name.to_a
      end
    end

    private

    def user_join
      "LEFT JOIN (
        SELECT COUNT(u.id) AS user_count,
               MAX(u.created_at) AS last_user_created_at,
               MAX(u.last_sign_in_at) AS last_login_at,
               h.community_id AS community_id
          FROM users u INNER JOIN households h ON h.id = u.household_id
          WHERE u.fake = 'f'
          GROUP BY h.community_id
        ) AS user_stats ON user_stats.community_id = communities.id"
    end

    def meal_join
      "LEFT JOIN (
        SELECT COUNT(m.id) AS meal_count,
               MAX(m.served_at) AS last_meal_served_at,
               m.community_id AS community_id
          FROM meals m INNER JOIN communities c ON c.id = m.community_id
          WHERE m.created_at > c.created_at
          GROUP BY m.community_id
        ) AS meal_stats ON meal_stats.community_id = communities.id"
    end

    def rsrv_join
      "LEFT JOIN (
        SELECT COUNT(r.id) AS rsrv_count,
               MAX(r.starts_at) AS last_rsrv_starts_at,
               rc.community_id AS community_id
          FROM reservations r INNER JOIN resources rc ON rc.id = r.resource_id
            INNER JOIN communities c ON c.id = rc.community_id
          WHERE r.created_at > c.created_at
          GROUP BY rc.community_id
        ) AS rsrv_stats ON rsrv_stats.community_id = communities.id"
    end

    def job_join
      "LEFT JOIN (
        SELECT COUNT(DISTINCT j.id) AS job_count,
               MAX(s.starts_at) AS last_job_starts_at,
               p.community_id AS community_id
          FROM work_shifts s INNER JOIN work_jobs j ON j.id = s.job_id
            INNER JOIN work_periods p ON p.id = j.period_id
            INNER JOIN communities c ON c.id = p.community_id
          WHERE j.created_at > c.created_at
          GROUP BY p.community_id
        ) AS job_stats ON job_stats.community_id = communities.id"
    end

    def txn_join
      "LEFT JOIN (
        SELECT COUNT(t.id) AS txn_count,
               MAX(t.created_at) AS last_txn_created_at,
               a.community_id AS community_id
          FROM transactions t INNER JOIN accounts a ON a.id = t.account_id
            INNER JOIN communities c ON c.id = a.community_id
          WHERE t.created_at > c.created_at
          GROUP BY a.community_id
        ) AS txn_stats ON txn_stats.community_id = communities.id"
    end
  end
end
