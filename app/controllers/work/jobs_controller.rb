module Work
  class JobsController < ApplicationController
    before_action -> { nav_context(:work, :jobs) }

    decorates_assigned :job

    def new
      prep_form_vars
      @job = Job.new(community: current_community, period: @period)
      authorize @job
    end

    private

    def prep_form_vars
      @periods = Period.for_community(current_community).active
      @period = @periods.first # This will change to use lens.
      @requesters = People::Group.for_community(current_community).by_name
    end
  end
end
