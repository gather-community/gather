# frozen_string_literal: true

module Work
  # Determines whether a given user taking a given shift would exceed the round limit currently in
  # force under a staggered period's round schedule.
  #
  # This is the single source of truth for the round limit. It always evaluates against the
  # *shift's own* period; a caller-supplied synopsis is used only if it was built for that same
  # period, and is otherwise discarded. Callers that supply nothing still get a correct answer, at
  # the cost of building a synopsis.
  class RoundLimitChecker
    attr_accessor :shift, :user

    def initialize(shift:, user:, synopsis: nil)
      self.shift = shift
      self.user = user
      @given_synopsis = synopsis
    end

    def exceeded?
      return false unless period.staggered?

      # Full community jobs don't count against the round limit.
      return false if shift.full_community?
      return false unless synopsis.staggering?

      limit = synopsis.staggering[:prev_limit]

      # A nil limit means the user's rounds are done and they can take whatever they like.
      return false if limit.nil?

      synopsis.regular_hours_for_user + shift.job_hours > limit
    end

    private

    def period
      shift.period
    end

    # Uses the given synopsis only if it was built for the shift's period. Guarding on this is what
    # keeps a caller from evaluating the limit against the wrong period, whether by mistake or by
    # feeding a period of their choosing into the URL.
    def synopsis
      @synopsis ||=
        if @given_synopsis&.period == period
          @given_synopsis
        else
          Synopsis.new(period: period, user: user)
        end
    end
  end
end
