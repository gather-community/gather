module Work
  class AssignmentsController < ApplicationController
    before_action -> { nav_context(:work, :signups) }
    decorates_assigned :jobs
    helper_method :sample_assignment

    def index
      authorize sample_assignment
      prepare_lenses(:"work/requester", :"work/period")
      @period = lenses[:period].object
      @jobs = policy_scope(Job).for_community(current_community).in_period(@period).
        includes(shifts: {assignments: :user}).by_title
      @cache_key = [@period.cache_key, @jobs.cache_key, lenses.cache_key].join("|")

      if request.xhr?
        render partial: "main"
      elsif @period.draft? || @period.archived?
        flash.now[:notice] = t("work.notices.#{@period.phase}")
      end
    end

    protected

    def klass
      Job
    end

    private

    def sample_assignment
      period = @period || Period.new(community: current_community)
      Assignment.new(shift: Shift.new(job: Job.new(period: period)))
    end
  end
end
