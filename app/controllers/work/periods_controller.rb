module Work
  class PeriodsController < ApplicationController
    before_action -> { nav_context(:work, :periods) }

    decorates_assigned :period, :periods
    helper_method :sample_period

    def index
      authorize sample_period
      @periods = policy_scope(Period).for_community(current_community).latest_first.page(params[:page])
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
