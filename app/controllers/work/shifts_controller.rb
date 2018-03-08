# frozen_string_literal: true

module Work
  # Controls job signup pages.
  class ShiftsController < ApplicationController
    before_action -> { nav_context(:work, :signups) }
    decorates_assigned :jobs
    helper_method :sample_shift

    def index
      authorize sample_shift
      prepare_lenses(:"work/requester", :"work/period")
      @period = lenses[:period].object
      @jobs = policy_scope(Job).for_community(current_community).in_period(@period)
        .includes(shifts: {assignments: :user}).by_title
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

    def sample_shift
      period = @period || Period.new(community: current_community)
      Shift.new(job: Job.new(period: period))
    end
  end
end
