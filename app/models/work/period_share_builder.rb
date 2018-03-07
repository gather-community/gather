module Work
  # Builds shares for all users in a period, with certain exceptions.
  class PeriodShareBuilder
    attr_accessor :period, :action

    def initialize(period)
      self.period = period
    end

    def build
      users.each do |user|
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
      # For existing periods, only new users will usually not have shares.
      # We don't want to assume they should get a portion.
      if @period.new_record?
        user.child? ? 0 : 1
      else
        nil
      end
    end

    def existing_shares_by_user_id
      @existing_shares_by_user_id ||= period.shares.index_by(&:user_id)
    end
  end
end
