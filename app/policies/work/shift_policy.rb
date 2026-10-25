# frozen_string_literal: true

module Work
  class ShiftPolicy < ApplicationPolicy
    alias shift record
    attr_accessor :synopsis

    class Scope < Scope
      def resolve
        allow_regular_users_in_community
      end
    end

    def initialize(user, record, synopsis: nil)
      super(user, record)
      self.synopsis = synopsis
    end

    # Controls whether we can see the index page outer wrapper including the period lens.
    def index_wrapper?
      active_in_community?
    end

    def index?
      active_in_community? && (active_admin_or?(:work_coordinator) || !shift.period_draft?)
    end

    def show?
      index?
    end

    # The signup link a user clicked can be out of date by the time it reaches us, so this check
    # names its conditions: the caller can ask why it refused and tell the user, rather than treating
    # every refusal as an authorization failure. Reasons are ordered so the most specific and most
    # actionable one wins: a signup of the user's own that already landed explains a full shift, and
    # either explains more than the round limit does.
    permission :signup? do
      deny_unless(:not_permitted) { index? }
      deny_unless(:period_closed) { shift.period_open? || shift.period_published? }
      deny_if(:already_signed_up) { !shift.double_signups_allowed? && shift.user_signed_up?(user) }
      deny_if(:slots_exceeded) { shift.taken? }
      deny_if(:round_limit_exceeded) { round_limit_exceeded? }
    end

    def unsignup?
      shift.period_open? && index?
    end

    def new?
      active_admin_or?(:work_coordinator)
    end

    def edit?
      new?
    end

    def create?
      new?
    end

    def update?
      new?
    end

    def destroy?
      new?
    end

    # Note this does not depend on a synopsis having been injected: the checker builds its own for
    # the shift's period when it needs one. That keeps plain `policy(shift).signup?` (as used by
    # ActionLink on the shift show page) honest.
    def round_limit_exceeded?
      RoundLimitChecker.new(shift: shift, user: user, synopsis: synopsis).exceeded?
    end
  end
end
