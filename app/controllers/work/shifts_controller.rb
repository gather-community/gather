# frozen_string_literal: true

module Work
  # Controls job signup pages.
  class ShiftsController < ApplicationController
    before_action -> { nav_context(:work, :signups) }
    decorates_assigned :shifts, :shift
    helper_method :sample_shift

    def index
      authorize sample_shift
      prepare_lenses(:search, :"work/shift", :"work/period")
      @period = lenses[:period].object
      scope_shifts
      @cache_key = [current_user.id, @period.cache_key, @shifts.cache_key, lenses.cache_key].join("|")

      if request.xhr?
        render partial: "shifts"
      elsif @period.draft? || @period.archived?
        flash.now[:notice] = t("work.notices.#{@period.phase}")
      end
    end

    # Called from AJAX on signup link click.
    # If there are no slots left, shift card will include error message.
    def signup
      @shift = Shift.find(params[:id])
      authorize @shift
      begin
        @shift.signup_user(current_user)
      rescue SlotsExceededError
        @error = t("work/shifts.slots_exceeded")
      rescue AlreadySignedUpError
        @error = t("work/shifts.already_signed_up")
      end
      render partial: "shift", locals: {shift: shift}
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

    def scope_shifts
      @shifts = policy_scope(Shift).for_community(current_community).in_period(@period)
        .includes(:job, assignments: :user).by_job_title.by_date

      case lenses[:shift].value
      when "open"
        @shifts = @shifts.open
      when "me"
        @shifts = @shifts.with_user(current_user)
      when "myhh"
        @shifts = @shifts.with_user(current_user.household.users)
      end

      @shifts = @shifts.from_requester(lenses[:shift].requester_id) if lenses[:shift].requester_id
      @shifts = @shifts.matching(lenses[:search].value) if lenses[:search].present?
    end
  end
end
