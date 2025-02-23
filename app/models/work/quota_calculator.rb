# frozen_string_literal: true

module Work
  # Calculates how many hours each person (or share) are implied by the current set of jobs for a period.
  class QuotaCalculator
    attr_accessor :period, :report, :hours_to_distribute, :portions_equalized, :quota

    delegate :shares, :total_portions, :fixed_slot_non_preassigned_hours, :by_user, to: :report

    def initialize(period)
      self.period = period
      self.report = Report.new(period: period)
    end

    # Recalculates the quota if the changes to the given trigger object necessitate it.
    def recalculate_and_save
      period.update!(quota: calculate)
    end

    # Distributes the hours that are not preassigned to the users/households in the community.
    # Accounts for shares. Works by making a list of discrete, share-adjusted levels of preassigned hours,
    # and then distributing hours to iteratively bring the users/households up to each level, until
    # all hours are distributed.
    # If there are a lot of preassigned hours, some users/households may have more than the final quota,
    # which is OK.
    def calculate
      return 0 if period.quota_none? || total_portions.zero?

      setup_vars
      sorted_levels.each_with_index do |level, i|
        break if i == sorted_levels.size - 1 || hours_to_distribute <= 0

        equalize_to_level(level, i)
      end
      distribute_leftover_hours if hours_to_distribute.positive?
      quota
    end

    private

    # Sets up variables for the computation.
    def setup_vars
      self.hours_to_distribute = fixed_slot_non_preassigned_hours
      self.portions_equalized = 0.0
      self.quota = sorted_levels[0]
    end

    # Brings the equilibrium up to the next discrete level.
    def equalize_to_level(level, index)
      portions_for_level = portions_by_level[level]
      diff_from_next = sorted_levels[index + 1] - level
      self.portions_equalized += portions_for_level

      # If it would take more than the remaining hours to equalize up to the next level,
      # we have to limit the amount to the remaining hours.
      amount_to_equalize = [portions_equalized * diff_from_next, hours_to_distribute].min

      self.hours_to_distribute -= amount_to_equalize
      self.quota += amount_to_equalize / portions_equalized
    end

    def distribute_leftover_hours
      self.quota += hours_to_distribute / total_portions
    end

    def portions_by_level
      return @portions_by_level if @portions_by_level

      @portions_by_level = Hash.new(0)
      grouped_shares.each do |shares|
        portions = shares.sum(&:portion)
        next if portions.zero?

        preassigned = shares.sum { |s| by_user[s.user_id].try(:[], :preassigned) || 0 }
        level = preassigned / portions
        @portions_by_level[level] += portions
      end
      @portions_by_level
    end

    def sorted_levels
      @sorted_levels ||= portions_by_level.keys.sort
    end

    # Arranges shares into groups depending on the period's quota_type setting.
    def grouped_shares
      @grouped_shares ||=
        if period.quota_by_household?
          shares.group_by(&:household_id).values
        else
          shares.map { |s| [s] }
        end
    end
  end
end
