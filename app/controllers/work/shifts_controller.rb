# frozen_string_literal: true

module Work
  # Controls job signup pages.
  class ShiftsController < WorkController
    before_action -> { nav_context(:work, :signups) }
    decorates_assigned :shifts, :shift
    helper_method :sample_shift, :synopsis, :shift_policy

    def index
      authorize(sample_shift, :index_wrapper?)
      prepare_lenses(:search, :"work/shift", :"work/period")
      @period = lenses[:period].object
      @shifts = policy_scope(Shift)
      @shifts = @shifts.none unless policy(sample_shift).index?

      if @period.nil?
        lenses.hide!
      else
        scope_shifts
        @cache_key = [current_user.id, @period.cache_key, @shifts.cache_key,
                      lenses.cache_key, params[:page] || 1].join("|")
        @autorefresh = !params[:norefresh] && (@period.draft? || @period.ready? || @period.open?)

        if request.xhr?
          render partial: "shifts"
        elsif @period.archived?
          flash.now[:notice] = t("work.phase_notices.shifts.archived")
        end
      end
    end

    def show
      @shift = Shift.find(params[:id])
      authorize @shift
    end

    # Called from AJAX on signup link click.
    # If there are no slots left, shift card will include error message.
    def signup
      @shift = Shift.find(params[:id])
      @period = @shift.period

      # Since we have a custom built policy object, we need to do our own custom authorization.
      skip_authorization && (shift_policy(shift).signup? || (return render_forbidden))

      begin
        @shift.signup_user(current_user)
        raise ENV["STUB_SIGNUP_ERROR"].constantize if Rails.env.test? && ENV["STUB_SIGNUP_ERROR"]
      rescue SlotsExceededError
        @error = t("work/shift.slots_exceeded")
      rescue AlreadySignedUpError
        @error = t("work/shift.already_signed_up")
      end

      if request.xhr?
        # Synopsis was already computed once for authorization. Force recalculation after change.
        @synopsis = nil

        render json: {
          shift: render_to_string(partial: "shift", locals: {shift: shift}),
          synopsis: render_to_string(partial: "synopsis")
        }
      else
        if @error
          flash[:error] = @error
        else
          flash[:success] = "You signed up successfully. Hooray!"
        end
        redirect_to(work_shifts_path)
      end
    end

    def unsignup
      @shift = Shift.find(params[:id])
      authorize @shift
      begin
        @shift.unsignup_user(current_user)
        flash[:success] = "Your signup was removed successfully."
      rescue NotSignedUpError
        flash[:error] = t("work/shift.not_signed_up")
      end
      redirect_to(work_shifts_path)
    end

    protected

    def klass
      Job
    end

    private

    def sample_shift
      period = @period || sample_period
      Shift.new(job: Job.new(period: period))
    end

    def scope_shifts
      @shifts = @shifts
        .in_community(current_community)
        .in_period(@period)
        .includes(job: {period: :community}, assignments: :user)
        .by_job_title
        .by_date
        .page(params[:page])
        .per(50)
      apply_shift_lens
      apply_search_lens
    end

    def apply_shift_lens
      @shifts =
        case lenses[:shift].value
        when "open" then @shifts.open
        when "me" then @shifts.with_user(current_user)
        when "myhh" then @shifts.with_user(current_user.household.users)
        when "notpre" then @shifts.with_non_preassigned_or_empty_slots
        else lenses[:shift].requester_id ? @shifts.from_requester(lenses[:shift].requester_id) : @shifts
        end
    end

    def apply_search_lens
      return if lenses[:search].blank?
      search = Work::Shift.search(
        query: {
          multi_match: {
            query: lenses[:search].value,
            type: :cross_fields,
            operator: :and
          }
        },
        # We set size to 10k because we don't need to worry about restricting the result set here.
        # It's restricted for us by the other scoping stuff.
        # TODO: This is a big problem because it doesn't scale. We need to change the above lens application
        # stuff to use the search fields, at least for period and community
        size: 10_000
      )
      @shifts = @shifts.merge(search.records.records)
    end

    # Custom-builds a ShiftPolicy object with the given shift, including the synopsis if appropriate.
    def shift_policy(shift)
      ShiftPolicy.new(current_user, shift, synopsis: shift.period.staggered? ? synopsis.object : nil)
    end

    def synopsis
      # Draper inferral is not working here for some reason.
      @synopsis ||= SynopsisDecorator.new(Synopsis.new(period: @period, user: current_user))
    end
  end
end
