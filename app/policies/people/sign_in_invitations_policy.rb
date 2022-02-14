# frozen_string_literal: true

module People
  class SignInInvitationsPolicy < ApplicationPolicy
    alias invited_user record

    def show?
      false
    end

    def create?
      !invited_user.child? && active_admin?
    end
  end
end
