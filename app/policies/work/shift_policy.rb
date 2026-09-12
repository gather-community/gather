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

    def signup?
      index? &&
        (shift.period_open? || shift.period_published?) &&
        (shift.double_signups_allowed? || !shift.user_signed_up?(user)) &&
        !shift.taken? &&
        !round_limit_exceeded?
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
