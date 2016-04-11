module Reservation
  class ReservationPolicy < ApplicationPolicy
    alias_method :reservation, :record

    def index?
      active?
    end

    def show?
      active?
    end

    def create?
      active?
    end

    def update?
      active_reserver? || admin?
    end

    def destroy?
      active_reserver? && (future? || recently_created?) || admin?
    end

    def permitted_attributes
      %i(name kind reserver_id resource_id sponsor_id starts_at ends_at guidelines_ok)
    end

    private

    delegate :future?, :recently_created?, to: :reservation

    def active_reserver?
      active? && reservation.user == user
    end
  end
end
