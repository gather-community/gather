module Work
  # Creates shares for all users in a period, with certain exceptions.
  class PeriodShareCreator
    attr_accessor :period

    def initialize(period)
      self.period = period
    end

    def create
      User.in_community(period.community).active.each do |user|
        next if user.age.try(:<, Share::MIN_AGE)
        next if existing_shares_by_user_id.key?(user.id)
        period.shares.create!(user: user, portion: user.child? ? 0 : 1)
      end
    end

    private

    def existing_shares_by_user_id
      @existing_shares_by_user_id ||= period.shares.index_by(&:user_id)
    end
  end
end
