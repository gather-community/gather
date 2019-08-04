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
      self.round_num = 1
      self.rounds = []
      setup_debug(debug)
      compute_shares_with_initial_need
      compute_shares_with_no_initial_need
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

    attr_accessor :target_share, :limits_by_cohort, :debug, :round_num
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

    def compute_shares_with_initial_need
      prepare_shares
      loop do
        shares = top_n_shares
        return if shares.all? { |s| s.current_min_need.zero? }
        shares.each do |share|
          share.rounds_completed += 1
          share.current_min_need -= share.hours_per_round
          next unless share == target_share
          time = auto_open_time + (round_num - 1) * round_duration.minutes
          limit = (quota * share.portion - share.current_min_need).ceil
          limit = nil if limit >= quota * share.portion
          rounds << {starts_at: time, limit: limit}
        end
        self.round_num = round_num + 1
      end
    end

    def compute_shares_with_no_initial_need
      return if shares_with_initial_need.include?(target_share)
      time = auto_open_time + (round_num - 1) * round_duration.minutes
      rounds << {starts_at: time, limit: nil}
    end

    def prepare_shares
      shares.each do |share|
        share.rounds_completed = 0
        share.current_min_need = share.portion * quota - preassigned_total_for(share)
        share.num_rounds = quota.zero? ? 1 : (share.current_min_need / max_hours_per_round).ceil
        share.hours_per_round = share.current_min_need / share.num_rounds
      end
    end

    def top_n_shares
      sorted = shares_with_initial_need.sort_by { |s| [s.rounds_completed, -s.current_min_need, s.id] }
      sorted[0, workers_per_round]
    end

    def shares_with_initial_need
      @shares_with_initial_need ||= shares.select { |s| s.current_min_need.positive? }
    end

    def max_hours_per_round
      quota.to_f / max_rounds_per_worker
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
