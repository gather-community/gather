# frozen_string_literal: true

module Work
  # Controls job signup pages.
  class ShiftsController < WorkController
    before_action -> { nav_context(:work, :signups) }

    # CSRF protection seems to cause issues from time to time probably due to heavy AJAX reloading.
    # CSRF is not a big security threat here so we're disabling.
    skip_before_action :verify_authenticity_token, only: %i[signup unsignup]

    # Since we have a specially built policy object, we need to do our own custom authorization.
    skip_after_action :verify_pundit_authorization, only: :signup

    # index doubles as the landing page, so it copes with a nil period itself. The rest can't.
    before_action :require_period, only: %i[show signup unsignup]

    decorates_assigned :shifts, :shift, :choosee, :meal

    helper_method :sample_shift, :synopsis, :shift_policy, :cache_key

    def index
      # Do this first, before anything builds a sample shift: it can affect policies and the cache
      # key, and building a sample shift would attach a stray unsaved job to @period that this save
      # would then try (and fail) to persist.
      @period&.auto_open_if_appropriate

      authorize(sample_shift, :index_wrapper?)
      prepare_lenses_and_set_contextual_vars

      @shifts = policy_scope(Shift)
      @shifts = @shifts.none unless policy(sample_shift).index?

      if @period.nil?
        return if redirect_to_sole_period_or_load_selectable(:signups)
        lenses.hide!
      else
        scope_shifts
        @autorefresh = !params[:norefresh] && (@period.pre_open? || @period.open?)

        if request.xhr?
          render_shifts_and_pagination_json
        elsif @period.archived?
          flash.now[:alert] = t("work.phase_notices.shifts.archived")
        end
      end
    end

    def show
      @shift = find_shift_in_period
      authorize(@shift)
      @meal = @shift.meal
    end

    # Called from AJAX on signup link click.
    # If there are no slots left, shift card will include error message.
    def signup
      prepare_lenses_and_set_contextual_vars
      @shift = find_shift_in_period

      begin
        authorize_and_do_signup_or_raise_error
        raise_stubbed_error_in_test_mode
      rescue RoundLimitExceededError
        @error = t("work/shift.round_limit_exceeded")
      rescue SlotsExceededError
        @error = t("work/shift.slots_exceeded")
      rescue AlreadySignedUpError
        @error = t("work/shift.already_signed_up")
      end

      if request.xhr?
        # Synopsis was already computed once for authorization. Force recalculation after change.
        @synopsis = nil
        render_shift_and_synopsis_json
      else
        if @error
          flash[:error] = @error
        else
          flash[:success] = "You signed up successfully. Hooray!"
        end
        redirect_to(work_period_shifts_path(@period))
      end
    end

    def unsignup
      prepare_lenses_and_set_contextual_vars
      @shift = find_shift_in_period
      authorize(@shift)

      if request.xhr?
        begin
          @shift.unsignup_user(@choosee)
        rescue NotSignedUpError
          @error = t("work/shift.not_signed_up")
        end
        render_shift_and_synopsis_json
      else
        begin
          @shift.unsignup_user(@choosee)
          flash[:success] = "Your signup was removed successfully."
        rescue NotSignedUpError
          flash[:error] = t("work/shift.not_signed_up")
        end
        redirect_to(work_period_shifts_path(@period))
      end
    end

    protected

    def klass
      Job
    end

    private

    def prepare_lenses_and_set_contextual_vars
      if params[:action] == "index"
        names = %i[search work/shift]
        default_date_filter = current_community.settings.work.default_date_filter.to_sym
        names << {"work/shift_date_range": {initial_selection: default_date_filter}}
      else
        names = []
      end
      names << :"work/period" << {"work/choosee": {chooser: current_user}}
      prepare_lenses(*names)
      @choosee = lenses[:choosee].selection || current_user
      return if @choosee == current_user
      flash.now[:notice] = t("work.choosing_as", name: choosee.full_name)
    end

    # Shifts are addressed as /work/:period_slug/signups/:id, so the shift must actually belong to
    # the period named in the URL. Scoping the lookup keeps that promise, and in particular stops a
    # requester from naming some other period in order to have the round limit computed against it.
    def find_shift_in_period
      Shift.in_period(@period).find(params[:id])
    end

    def render_shift_and_synopsis_json
      render(json: {
        shift: render_to_string(partial: "shift", locals: {shift: shift}),
        synopsis: render_to_string(partial: "synopsis")
      })
    end

    # We render shifts and pagination separately so we don't have to render the "choose as" dropdown
    # every refresh (saving a few database hits).
    def render_shifts_and_pagination_json
      json = {
        shifts: render_to_string(partial: "shifts"),
        pagination: render_to_string(partial: "pagination")
      }
      delay_rendered_response_in_test_mode
      render(json: json)
    end

    def sample_shift
      period = @period || sample_period
      Shift.new(job: Job.new(period: period))
    end

    def scope_shifts
      @shifts = @shifts
        .in_community(current_community)
        .in_period(@period)
        .includes(:meal, job: {period: :community}, assignments: {user: {photo_attachment: :blob}})
        .by_job_title
        .by_date
        .page(params[:page])
        .per(48) # multiple of 2, 3, & 4
      apply_shift_lens
      apply_search_lens
      apply_date_range_lens
    end

    # We do our own authorization here so that we can tell the user why a signup was refused. The
    # link they clicked may have been out of date: their own signup landed already, or someone else
    # took the last slot. Those refusals belong on the shift card as a message, so we ask the policy
    # for its reason and raise the matching error; the rest are real authorization failures. These
    # are the same errors #signup_user raises when a competing request beats us to the write.
    def authorize_and_do_signup_or_raise_error
      policy = shift_policy(@shift)
      reason = policy.with_reason.signup?
      return @shift.signup_user(@choosee) if reason.nil?
      error = signup_errors[reason]
      raise error if error
      raise Pundit::NotAuthorizedError, query: :signup?, record: @shift, policy: policy
    end

    # Reasons ShiftPolicy can give for refusing a signup that the user can see and act on, mapped to
    # the errors that put each one on the shift card. Any other reason is an authorization failure.
    # A method rather than a constant because these classes are defined in work/shift.rb, which
    # isn't necessarily loaded when this class body is evaluated.
    def signup_errors
      {already_signed_up: AlreadySignedUpError,
       slots_exceeded: SlotsExceededError,
       round_limit_exceeded: RoundLimitExceededError}
    end

    def raise_stubbed_error_in_test_mode
      raise ENV["STUB_SIGNUP_ERROR"].constantize if Rails.env.test? && ENV["STUB_SIGNUP_ERROR"]
    end

    # Simulates a slow network: the response is already rendered, so it carries pre-delay state.
    # Lets a system spec keep a refresh in flight across a signup. See spec/system/work/signup_spec.rb.
    def delay_rendered_response_in_test_mode
      return unless Rails.env.test? && ENV["STUB_SHIFTS_RESPONSE_DELAY"]
      sleep(ENV["STUB_SHIFTS_RESPONSE_DELAY"].to_f)
    end

    def apply_shift_lens
      @shifts =
        case lenses[:shift].value
        when "open" then @shifts.open
        when "you" then @shifts.with_user(@choosee)
        when "yourhh" then @shifts.with_user(@choosee.household.users)
        when "notpre" then @shifts.with_non_preassigned_or_empty_slots
        else lenses[:shift].requester_id ? @shifts.from_requester(lenses[:shift].requester_id) : @shifts
        end
    end

    def apply_search_lens
      return if lenses[:search].blank?
      search = Work::Shift.search(
        query: {
          multi_match: {
            fields: Work::Shift.indexed_fields,
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

    def apply_date_range_lens
      return if lenses[:dates].selection == :all
      if lenses[:dates].selection == :curftr
        @shifts = @shifts.current_future
      elsif lenses[:dates].selection == :past
        @shifts = @shifts.past
      end
    end

    # Custom-builds a ShiftPolicy object with the given shift, including the synopsis if appropriate.
    def shift_policy(shift)
      ShiftPolicy.new(@choosee, shift, synopsis: shift.period.staggered? ? synopsis.object : nil)
    end

    def synopsis
      raise "period must be set to build synopsis" unless @period
      # Draper inferral is not working here for some reason.
      @synopsis ||= SynopsisDecorator.new(Synopsis.new(period: @period, user: @choosee))
    end

    # Cache key for the index page.
    def cache_key
      chunks = [@choosee.id, @period, @shifts, lenses, params[:page] || 1]

      # Need to include current minutes/5 if staggered because the round limit calculations
      # may change things just with the passage of time. We know things only change this way at 5-minute
      # increments though.
      chunks << (Time.current.seconds_since_midnight / 300).floor if @period.staggered?

      chunks
    end
  end
end
