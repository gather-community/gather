# frozen_string_literal: true

module People
  class SignInInvitationsPolicy < ApplicationPolicy
    def show?
      false
    end

    def create?
      active_admin?
    end
  end
end
