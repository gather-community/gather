# frozen_string_literal: true

module Work
  # Calculates the current limit and next round start time and limit for a given share.
  class RoundCalculator
    attr_accessor :next_num, :next_limit, :prev_limit

    def initialize(share:)
      self.share = share
      if auto_open_time.blank? || workers_per_round.blank? || round_duration.blank? || hours_per_round.blank?
        raise ArgumentError, "Required period parameters not set"
      end
      self.next_num = 0
      self.next_limit = 0
      self.prev_limit = 0
      compute
      raise ArgumentError, "Target share is not in period" if target_cohort.nil?
    end

    def next_starts_at
      return nil if next_num.nil?
      # Can't memoize this because it's used inside the compute method.
      auto_open_time + (next_num - 1) * round_duration
    end

    private

    attr_accessor :share, :limits_by_cohort

    delegate :period, to: :share
    delegate :shares, :quota, :auto_open_time, :workers_per_round,
      :round_duration, :hours_per_round, to: :period

    # Determines the number of the next round for the given share by iterating through
    # rounds until we reach the appropriate round. To iterate through rounds we cycle through
    # cohorts, increasing their hour limit each time.
    def compute
      round_limit = 0
      cohorts.cycle do |cohort|
        round_limit += hours_per_round if cohort == cohorts.first
        bump_next_num_if_anyone_can_pick(cohort, round_limit)
        next unless cohort == target_cohort
        break if update_target_cohort(round_limit)
      end
    end

    def bump_next_num_if_anyone_can_pick(cohort, limit)
      # We skip (don't increment round number) a cohort
      # if nobody from it can pick withiin the current limit. That way we don't waste time.
      self.next_num += 1 if anyone_can_pick?(cohort, limit)
    end

    def update_target_cohort(limit)
      self.prev_limit = next_limit if next_limit_exceeds_target_user_preassigned?
      self.next_limit = limit
      return false unless done?
      handle_edge_cases
      true
    end

    def handle_edge_cases
      self.next_limit = nil if next_limit >= quota
      return unless Time.current > next_starts_at
      self.prev_limit = nil
      self.next_num = nil
    end

    # Stop if limit is high enough and the 'next' round has a start time after current.
    # Or if next_limit exceeds quota, we know that enough time has passed since auto start
    # that there is effectively no limit, so we can also stop.
    def done?
      next_limit_exceeds_target_user_preassigned? && next_starts_at > Time.current || next_limit >= quota
    end

    def next_limit_exceeds_target_user_preassigned?
      next_limit > preassigned_total_for(share.user_id)
    end

    # Cohort containing the target share.
    def target_cohort
      @target_cohort ||= cohorts.detect { |c| c.include?(share) }
    end

    # Splits shares into groups (cohorts) of size `workers_per_round`.
    def cohorts
      # Order by ID so that the order is consistent between runs, even if shares deleted or inserted.
      @cohorts ||= sorted_shares.each_slice(workers_per_round).to_a
    end

    def sorted_shares
      shares.nonzero.order(:id).sort_by { |s| preassigned_total_for(s.user_id) }
    end

    # Checks if any share in the given cohort has fewer pre-assigned hours than the given limit.
    def anyone_can_pick?(cohort, limit)
      cohort.any? { |s| preassigned_total_for(s.user_id) < limit }
    end

    def preassigned_total_for(user_id)
      fixed_slot_preassigned_hours_by_user_id[user_id] || 0
    end

    # Efficiently loads preassigned totals per user for fixed slot jobs only.
    def fixed_slot_preassigned_hours_by_user_id
      @fixed_slot_preassigned_hours_by_user_id ||= Work::Assignment
        .select("user_id, SUM(work_jobs.hours) AS total_hours")
        .joins(shift: :job)
        .in_period(period)
        .fixed_slot
        .preassigned
        .group(:user_id)
        .map { |r| [r[:user_id], r[:total_hours]] }
        .to_h
    end
  end
end
