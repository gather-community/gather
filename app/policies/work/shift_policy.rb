# frozen_string_literal: true

module Work
  class ShiftPolicy < ApplicationPolicy
    alias shift record
    attr_accessor :synopsis

    delegate :job_hours, :full_community?, to: :shift

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

    def round_limit_exceeded?
      !synopsis.nil? && synopsis.staggering? && !round_limit.nil? && !full_community? &&
        user_regular_hours + job_hours > round_limit
    end

    private

    def user_regular_hours
      # The regular jobs info is always the first element of the array.
      synopsis.for_user[0][:got]
    end

    def round_limit
      synopsis.staggering[:prev_limit]
    end
  end
end
