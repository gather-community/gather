module Work
  class PeriodsController < ApplicationController
    before_action -> { nav_context(:work, :periods) }

    decorates_assigned :period, :periods
    helper_method :sample_period

    def index
      authorize sample_period
      @periods = policy_scope(Period).for_community(current_community).latest_first.page(params[:page])
    end

    def new
      @period = Period.new_with_defaults(current_community)
      authorize @period
      prep_form_vars
    end

    def edit
      @period = Period.find(params[:id])
      authorize @period
      prep_form_vars
    end

    def create
      @period = Period.new(community: current_community)
      @period.assign_attributes(period_params)
      authorize @period
      if @period.save
        flash[:success] = "Period created successfully."
        redirect_to work_periods_path
      else
        set_validation_error_notice(@period)
        prep_form_vars
        render :new
      end
    end

    def update
      @period = Period.find(params[:id])
      authorize @period
      if @period.update_attributes(period_params)
        flash[:success] = "Period updated successfully."
        redirect_to work_periods_path
      else
        set_validation_error_notice(@period)
        prep_form_vars
        render :edit
      end
    end

    protected

    def klass
      Period
    end

    private

    def sample_period
      Period.new(community: current_community)
    end

    def prep_form_vars
      build_users_by_kind_table
      build_and_populate_shares_by_user_table
    end

    def users
      @users ||= policy_scope(User).active.by_name.in_community(current_community).decorate.tap do |users|
        users.reject! { |c| c.age.try(:<, Share::MIN_AGE) }
      end
    end

    def build_users_by_kind_table
      @users_by_kind = users.group_by(&:kind)
    end

    def build_and_populate_shares_by_user_table
      shares = policy_scope(Share).for_period(@period)
      @shares_by_user = shares.index_by(&:user_id)
      users.each { |u| @shares_by_user[u.id] ||= Share.new(user: u, period: @period, portion: nil) }
    end

    # Pundit built-in helper doesn't work due to namespacing
    def period_params
      params.require(:work_period).permit(policy(@period).permitted_attributes)
    end
  end
end
