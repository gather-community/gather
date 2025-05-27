# frozen_string_literal: true

module GDrive
  class ConfigPolicy < ApplicationPolicy
    alias_method :config, :record

    def show?
      active_admin?
    end

    def new?
      active_admin?
    end

    def create?
      active_admin?
    end

    def edit?
      active_admin?
    end

    def update?
      active_admin?
    end

    def destroy?
      active_admin?
    end

    def permitted_attributes
      %i[org_user_id client_id client_secret_to_write]
    end
  end
end
