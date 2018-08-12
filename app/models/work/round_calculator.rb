# frozen_string_literal: true

module Work
  # Calculates the current limit and next round start time and limit for a given share.
  class RoundCalculator
    attr_accessor :next_limit, :prev_limit

    # Debug mode runs through the full process regardless of time and target share.
    def initialize(target_share:, debug: false)
      self.target_share = target_share
      if auto_open_time.blank? || workers_per_round.blank? ||
          round_duration.blank? || max_rounds_per_worker.blank?
        raise ArgumentError, "Required period parameters not set"
      end
      self.now = Time.current
      self.next_num = 0
      self.next_limit = 0
      self.prev_limit = 0
      setup_debug(debug)
      compute
      raise ArgumentError, "Target share is not in period" if target_cohort.nil?
    end

    def next_starts_at
      return nil if next_num.nil?
      # Can't memoize this because it's used inside the compute method.
      auto_open_time + (next_num - 1) * round_duration
    end

    private

    attr_accessor :target_share, :limits_by_cohort, :next_num, :debug, :now
    alias debug? debug

    delegate :period, to: :target_share
    delegate :shares, :quota, :auto_open_time, :workers_per_round,
      :round_duration, :max_rounds_per_worker, to: :period

    # Determines the number of the next round for the given share by iterating through
    # rounds until we reach the appropriate round. To iterate through rounds we cycle through
    # cohorts, increasing their hour limit each time.
    def compute
      round_min_need = quota # Represents the minimum distance to quota fulfillment allowed in this round.
      cohorts.cycle do |cohort|
        round_min_need -= hours_per_round if cohort == cohorts.first
        bump_next_num_if_anyone_can_pick(cohort, round_min_need)
        next unless cohort == target_cohort
        break if update_target_cohort(round_min_need)
      end
    end

    def bump_next_num_if_anyone_can_pick(cohort, min_need)
      # We skip (don't increment round number) a cohort
      # if nobody from it can pick withiin the current min_need. That way we don't waste time.
      if anyone_can_pick?(cohort, min_need)
        self.next_num = next_num + 1
        log("Round #{next_num}: Users #{cohort.map(&:user_id)}, Min Need #{min_need}")
      else
        log("Nobody in cohort #{cohort.map(&:user_id)} could pick given min need #{min_need}")
      end
    end

    # Updates round pick limits for the target cohort.
    # Returns true if we've reached the stopping condition for the calculator.
    def update_target_cohort(min_need)
      limit = limit_from_min_need(target_share, min_need)
      self.prev_limit = next_limit if target_user_can_pick_next_round?
      self.next_limit = limit
      return false unless done?
      self.prev_limit = self.next_num = nil if now > next_starts_at
      true
    end

    def target_user_can_pick_next_round?
      next_limit > preassigned_total_for(target_share)
    end

    # Stop if target user can pick next round and next round has a start time after current.
    # Or if next_limit is nil, we know that enough time has passed since auto start
    # that there is effectively no limit, so we can also stop.
    def done?
      next_limit.nil? || target_user_can_pick_next_round? && next_starts_at > now
    end

    # Calculates the current pick limit for the given share based on the given min need.
    def limit_from_min_need(share, min_need)
      return nil if min_need <= 0.00001
      [(quota * share.portion - min_need).ceil, 0].max
    end

    def hours_per_round
      quota.to_f / max_rounds_per_worker
    end

    # Cohort containing the target share.
    def target_cohort
      @target_cohort ||= cohorts.detect { |c| c.include?(target_share) }
    end

    # Splits shares into groups (cohorts) of size `workers_per_round`.
    def cohorts
      # Order by ID so that the order is consistent between runs, even if shares deleted or inserted.
      @cohorts ||= sorted_shares.each_slice(workers_per_round).to_a
    end

    # Sorts shares by how many hours each needs to get to their portion-adjusted quota.
    # We sort by ID, which we elsewhere ensure is random. This ensures consistent among those
    # with equal preassigned totals even if other things change.
    def sorted_shares
      shares.nonzero.order(:id).sort_by { |s| preassigned_total_for(s) - s.portion * quota }
    end

    # Checks if any share in the given cohort has fewer pre-assigned hours than the given limit.
    def anyone_can_pick?(cohort, min_need)
      cohort.any? { |s| preassigned_total_for(s) < (limit_from_min_need(s, min_need) || 1e9) }
    end

    def preassigned_total_for(share)
      fixed_slot_preassigned_hours_by_user_id[share.user_id] || 0
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

    # If in debug mode, we use a target share in the last cohort and go way into the future to ensure
    # the full process is run through.
    def setup_debug(debug)
      self.debug = debug
      return unless debug?
      self.target_share = cohorts.last[0]
      self.now = auto_open_time + 1.year
    end

    def log(str)
      Rails.logger.debug(str) if debug?
    end
  end
end
