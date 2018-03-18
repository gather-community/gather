module Work
  class PeriodsController < ApplicationController
    include Destructible

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
        QuotaCalculator.new(@period).recalculate_and_save
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
        QuotaCalculator.new(@period).recalculate_and_save
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
      @share_builder = PeriodShareBuilder.new(@period)
      @share_builder.build
      @users_by_kind = UserDecorator.decorate_collection(@share_builder.users).group_by(&:kind)
      @shares_by_user = @period.shares.index_by(&:user_id)
    end

    # Pundit built-in helper doesn't work due to namespacing
    def period_params
      params.require(:work_period).permit(policy(@period).permitted_attributes)
    end
  end
end
