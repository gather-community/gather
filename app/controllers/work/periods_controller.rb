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

    protected

    def klass
      Period
    end

    private

    def sample_period
      Period.new(community: current_community)
    end

    def prep_form_vars
    end

    # Pundit built-in helper doesn't work due to namespacing
    def period_params
      params.require(:work_period).permit(policy(@period).permitted_attributes)
    end
  end
end
