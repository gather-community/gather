# frozen_string_literal: true

module Work
  # Calculates the round schedule for a given share.
  # Exposes current limit, next round start time and next limit.
  class RoundCalculator
    attr_accessor :rounds

    # Debug mode runs through the full process regardless of time and target share.
    def initialize(target_share:, debug: false)
      self.target_share = target_share
      ensure_key_params
      self.next_num = 0
      self.rounds = []
      setup_debug(debug)
      compute
      raise ArgumentError, "Target share is not in period" if target_cohort.nil?
    end

    def prev_limit
      prev_round ? prev_round[:limit] : 0
    end

    def next_limit
      next_round ? next_round[:limit] : nil
    end

    def next_starts_at
      next_round ? next_round[:starts_at] : nil
    end

    private

    attr_accessor :target_share, :limits_by_cohort, :next_num, :debug
    alias debug? debug

    delegate :period, to: :target_share
    delegate :shares, :quota, :auto_open_time, :workers_per_round,
      :round_duration, :max_rounds_per_worker, to: :period

    def ensure_key_params
      if auto_open_time.blank? || workers_per_round.blank? ||
          round_duration.blank? || max_rounds_per_worker.blank?
        raise ArgumentError, "Required period parameters not set"
      end
    end

    # Gets the next round from the rounds array based on the current time. Nil if none found.
    def next_round
      rounds.detect { |r| r[:starts_at] > Time.current }
    end

    # Gets the previous round from the rounds array based on the current time. Nil if none found.
    def prev_round
      rounds.select { |r| r[:starts_at] <= Time.current }.last
    end

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
      if limit.nil? || limit > preassigned_total_for(target_share)
        time = auto_open_time + (next_num - 1) * round_duration.minutes
        rounds << {starts_at: time, limit: limit}
      end
      limit.nil?
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

    # If in debug mode, we use a target share in the last cohort to ensure the full process is run.
    def setup_debug(debug)
      self.debug = debug
      return unless debug?
      self.target_share = cohorts.last[0]
    end

    def log(str)
      Rails.logger.debug(str) if debug?
    end
  end
end
