# frozen_string_literal: true

module Work
  # Builds shares for all users in a period, with certain exceptions.
  class PeriodShareBuilder
    attr_accessor :period, :action

    def initialize(period)
      self.period = period
    end

    def build
      # We randomize the users because staggering calculations depend on share ID for randomness.
      users.shuffle.each do |user|
        next if existing_shares_by_user_id.key?(user.id)

        period.shares.build(user: user, portion: initial_portion_for(user))
      end
    end

    def users
      @users ||= User.active.by_name_adults_first.in_community(period.community).to_a.tap do |users|
        users.reject! { |c| c.age.try(:<, Settings.work.min_age) }
      end
    end

    private

    def initial_portion_for(user)
      # For new periods, we want to set a sensible default.
      # For existing periods with quota_type none, we want to have shares pre-built in case
      # the user wants to change the quota type to non-none. They will get discarded if not used.
      # For existing periods with quota_type not none, only new users will usually not have shares.
      # We don't want to assume they should get a portion.
      return unless @period.new_record? || @period.quota_none?

      user.full_access? ? 1 : 0
    end

    def existing_shares_by_user_id
      @existing_shares_by_user_id ||= period.shares.index_by(&:user_id)
    end
  end
end
