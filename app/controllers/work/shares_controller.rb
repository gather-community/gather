module Work
  class SharesController < ApplicationController
    before_action -> { nav_context(:work, :shares) }

    def index
      authorize sample_share
      prepare_lenses(:"work/period")
      @period = Period.find_by(id: lenses[:period].value) # May be nil
      if @period.nil?
        skip_policy_scope
        lenses.hide!
      else
        users = policy_scope(User).active.by_name.in_community(current_community).decorate
        users = users.reject { |c| c.age.try(:<, Share::MIN_AGE) }
        @users_by_kind = users.group_by(&:kind)

        shares = policy_scope(Share).where(period: @period)
        @shares_by_user = shares.index_by(&:user)
        users.each { |u| @shares_by_user[u] ||= Share.new(user: u, period: @period) }
      end
    end

    private

    def sample_share
      Share.new(period: Period.new(community: current_community))
    end
  end
end
