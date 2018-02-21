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
        @shares = policy_scope(Share).where(period: @period)
      end
    end

    private

    def sample_share
      Share.new(period: Period.new(community: current_community))
    end
  end
end
