module Work
  class SharesController < ApplicationController
    before_action -> { nav_context(:work, :shares) }

    # Renders a collection of dropdown boxes for each active user.
    def index
      authorize sample_share
      prepare_lenses(:"work/period")
      @period = lenses[:period].object
      if @period.nil?
        skip_policy_scope
        lenses.hide!
      else
        users = policy_scope(User).active.by_name.in_community(current_community).decorate
        users = users.reject { |c| c.age.try(:<, Share::MIN_AGE) }
        @users_by_kind = users.group_by(&:kind)

        shares = policy_scope(Share).for_period(@period)
        @shares_by_user = shares.index_by(&:user_id)
        users.each { |u| @shares_by_user[u.id] ||= Share.new(user: u, period: @period, portion: nil) }
      end
    end

    # Creates/updates all shares for current period at once.
    def create
      authorize sample_share
      @period = Period.find(params[:work_period].delete(:id))
      permitted = policy(sample_share).permitted_attributes << :id
      @period.assign_attributes(params.require(:work_period).permit(shares_attributes: permitted))
      @period.save(validate: false) # There is nothing to validate regarding shares.
      flash[:success] = "Shares updated successfully."
      redirect_to work_shares_path
    end

    private

    def sample_share
      Share.new(period: Period.new(community: current_community))
    end
  end
end
