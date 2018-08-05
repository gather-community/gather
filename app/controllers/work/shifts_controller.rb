# frozen_string_literal: true

module Work
  # Controls job signup pages.
  class ShiftsController < WorkController
    before_action -> { nav_context(:work, :signups) }
    decorates_assigned :shifts, :shift
    helper_method :sample_shift, :synopsis

    def index
      authorize sample_shift
      prepare_lenses(:search, :"work/shift", :"work/period")
      @period = lenses[:period].object
      @shifts = policy_scope(Shift)

      if @period.nil?
        lenses.hide!
      else
        scope_shifts
        @cache_key = [current_user.id, @period.cache_key, @shifts.cache_key,
                      lenses.cache_key, params[:page] || 1].join("|")
        @autorefresh = !params[:norefresh] && (@period.draft? || @period.open?)
        @synopsis = Synopsis.new(period: @period, user: current_user)

        if request.xhr?
          render partial: "shifts"
        elsif @period.draft? || @period.archived?
          flash.now[:notice] = t("work.notices.#{@period.phase}")
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
      authorize @shift
      begin
        @shift.signup_user(current_user)
        raise ENV["STUB_SIGNUP_ERROR"].constantize if Rails.env.test? && ENV["STUB_SIGNUP_ERROR"]
      rescue SlotsExceededError
        @error = t("work/shift.slots_exceeded")
      rescue AlreadySignedUpError
        @error = t("work/shift.already_signed_up")
      end

      if request.xhr?
        @synopsis = Synopsis.new(period: shift.period, user: current_user)
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

    def synopsis
      # Draper inferral is not working here for some reason.
      SynopsisDecorator.new(@synopsis)
    end
  end
end
