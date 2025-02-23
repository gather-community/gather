# frozen_string_literal: true

module Work
  # Assembles statistics on a work period and optionally for a given user.
  class Report
    attr_accessor :period, :user

    # Quota is pre-calculated and stored on the period.
    delegate :quota, :quota_by_user?, :quota_by_household?, :quota_none?, to: :period

    def initialize(period:, user: nil)
      self.period = period
      self.user = user
    end

    def fixed_slots
      @fixed_slots ||= fixed_slot_jobs.sum(&:total_slots)
    end

    def by_user
      @by_user ||= assignments.group_by(&:user_id).tap do |hash|
        hash.each do |user_id, assigns|
          hash[user_id] = {}
          hash[user_id][:preassigned] = assigns.select(&:preassigned?).sum(&:shift_hours)
          hash[user_id][:fixed_slot] = assigns.select(&:fixed_slot?).sum(&:shift_hours)
          assigns.each do |assign|
            next unless assign.full_community?

            hash[user_id][assign.job] ||= 0
            hash[user_id][assign.job] += assign.shift_hours
          end
          hash[user_id][:total] = assigns.sum(&:shift_hours)
        end
      end
    end

    def shares_by_user
      @shares_by_user ||= shares.index_by(&:user_id)
    end

    # Gets period shares via the for_period method that excludes inactive users.
    def shares
      @shares ||= Share.for_period(period).includes(:period, user: :household)
    end

    def users
      # Exclude users with no share AND no hours
      @users ||=
        if period.quota_none?
          assignments.map(&:user).uniq.sort_by { |u| u.name.downcase }
        else
          shares.by_user_name.reject do |s|
            s.zero? && (by_user.dig(s.user_id, :total) || 0).zero?
          end.map(&:user)
        end
    end

    def households
      # Exclude users with no share AND no hours
      @households ||= users.map(&:household).uniq.sort_by { |h| h.name.downcase }
    end

    def total_portions
      @total_portions ||= shares.to_a.sum(&:portion)
    end

    def full_community_jobs
      @full_community_jobs ||= all_jobs.select(&:full_community?)
    end

    def fixed_slot_non_preassigned_hours
      @fixed_slot_non_preassigned_hours ||= fixed_slot_hours - fixed_slot_preassigned_hours
    end

    def fixed_slot_hours
      @fixed_slot_hours ||= fixed_slot_jobs.sum { |j| j.total_slots * j.hours }
    end

    private

    def all_jobs
      @all_jobs ||= period.jobs.includes(shifts: {assignments: :user}).to_a
    end

    def assignments
      @assignments ||= all_jobs.flat_map(&:assignments)
    end

    def fixed_slot_jobs
      @fixed_slot_jobs ||= all_jobs.select(&:fixed_slot?)
    end

    def fixed_slot_preassigned_hours
      @fixed_slot_preassigned_hours ||= by_user.values.sum { |h| h[:preassigned] }
    end
  end
end
