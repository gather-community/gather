# frozen_string_literal: true

module Work
  # Calculates data for synopsis status message.
  class Synopsis
    # Duck type for Job
    REGULAR_BUCKET = OpenStruct.new(title: I18n.t("work.synopsis.regular"))

    attr_accessor :period, :user, :for_user, :for_household, :staggering, :done
    alias done? done

    delegate :quota_type, to: :period

    def initialize(period:, user:)
      self.period = period
      self.user = user
      @share_for = {}
      return if !period.open? || period.quota_none? || share_for(:user).zero?
      self.for_user = obligations_for(:user)
      period.quota_by_person? ? handle_by_person_quota : handle_by_household_quota
      handle_staggering
    end

    def empty?
      for_user.nil?
    end

    def staggering?
      staggering.present?
    end

    private

    def handle_by_person_quota
      self.done = all_ok?(for_user)
    end

    def handle_by_household_quota
      self.for_household = obligations_for(:household)
      self.done = all_ok?(for_household)

      # If household is all set, this overrides all self obligations to be ok.
      for_user.each { |o| o[:ok] = true } if done?
    end

    def handle_staggering
      return unless period.staggered?
      calc = RoundCalculator.new(target_share: share_for(:user))
      self.staggering = %i[prev_limit next_limit next_starts_at].map { |a| [a, calc.send(a)] }.to_h
    end

    def obligations_for(who)
      buckets.map do |bucket|
        hours = assigned_hours_for(who, bucket)
        ttl = quota_for(who, bucket)
        ok = round_next_half(hours) >= round_next_half(ttl)
        {bucket: bucket, got: hours, ttl: ttl, ok: ok}
      end
    end

    def all_ok?(obligation)
      obligation.all? { |o| o[:ok] }
    end

    def quota_for(who, bucket)
      (bucket == REGULAR_BUCKET ? period.quota : bucket.hours) * share_for(who)
    end

    def assigned_hours_for(who, bucket)
      scope = Assignment.where(user: users(who)).in_period(period).includes(shift: :job)
      if bucket == REGULAR_BUCKET
        scope.merge(Job.fixed_slot).sum("work_jobs.hours")
      else
        # For full community jobs, shift hours are different from job hours, so SQL sum won't work.
        scope.where("work_shifts.job_id": bucket.id).to_a.sum(&:shift_hours)
      end
    end

    def share_for(who)
      @share_for[who] ||= Share.for_period(period).where(user: users(who)).sum(:portion)
    end

    def users(who)
      who == :household ? user.household.users : [user]
    end

    def buckets
      @buckets ||= [REGULAR_BUCKET] + Job.full_community.by_title.in_period(period)
    end

    def round_next_half(num)
      (num * 2).ceil.to_f / 2
    end
  end
end
