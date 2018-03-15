# frozen_string_literal: true

module Work
  # Calculates how many hours each person (or share) are implied by the current set of jobs for a period.
  class QuotaCalculator
    attr_accessor :period, :hours_to_distribute, :portions_equalized, :quota

    def initialize(period)
      self.period = period
    end

    # Distributes the hours that are not preassigned to the users/households in the community.
    # Accounts for shares. Works by making a list of discrete, share-adjusted levels of preassigned hours,
    # and then distributing hours to iteratively bring the users/households up to each level, until
    # all hours are distributed.
    # If there are a lot of preassigned hours, some users/households may have more than the final quota,
    # which is OK.
    def calculate
      return 0 if total_portions.zero?
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
      self.hours_to_distribute = total_unassigned
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
      shares.each do |share|
        next if share.portion.zero?
        level = (preassigned_by_user[share.user_id] || 0) / share.portion
        @portions_by_level[level] += share.portion
      end
      @portions_by_level
    end

    def sorted_levels
      @sorted_levels ||= portions_by_level.keys.sort
    end

    def preassigned_by_user
      @preassigned_by_user ||= assignments.select(&:preassigned?).group_by(&:user_id).tap do |hash|
        hash.each do |user, assignments|
          hash[user] = assignments.sum(&:hours)
        end
      end
    end

    # Gets period shares via the for_period method that excludes inactive users.
    def shares
      @shares ||= Share.for_period(period).to_a
    end

    # Gets fixed slot jobs only and eager loads
    def jobs
      @jobs ||= period.jobs.includes(shifts: :assignments).fixed_slot.to_a
    end

    def assignments
      @assignments ||= jobs.flat_map(&:assignments)
    end

    def total_portions
      @total_portions ||= shares.sum(&:portion)
    end

    def total_hours
      @total_hours ||= jobs.sum { |j| j.total_slots * j.hours }
    end

    def total_preassigned
      @total_preassigned ||= preassigned_by_user.values.sum
    end

    def total_unassigned
      @total_unassigned ||= total_hours - total_preassigned
    end
  end
end
