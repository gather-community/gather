module Work
  class AssignmentsController < ApplicationController
    before_action -> { nav_context(:work, :assignments) }
    decorates_assigned :jobs
    helper_method :sample_assignment

    def index
      authorize sample_assignment
      prepare_lenses(:"work/requester", :"work/period")
      @period = lenses[:period].object
      @jobs = policy_scope(Job).for_community(current_community).in_period(@period).
        includes(shifts: {assignments: :user}).by_title
      @cache_key = [@period.cache_key, @jobs.cache_key, lenses.cache_key].join("|")

      # We pass this method to the view as an ivar so it can stay private but still get called from
      # within the cached block.
      @build_blank_assignments = method(:build_blank_assignments)

      if request.xhr?
        render partial: "main"
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

    # Build blank assignments for any shifts that are not fully taken. These will be rendered
    # as signup links.
    def build_blank_assignments
      @jobs.each do |job|
        job.shifts.each do |shift|
          shift.assignments.build unless shift.all_slots_taken?
        end
      end
    end
  end
end
