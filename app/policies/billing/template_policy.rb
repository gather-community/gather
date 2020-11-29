# frozen_string_literal: true

module Billing
  class TemplatePolicy < ApplicationPolicy
    alias template record

    class Scope < Scope
      def resolve
        allow_admins_in_community_or(:biller)
      end
    end

    def index?
      active_admin_or?(:biller)
    end

    def show?
      index?
    end

    def new?
      index?
    end

    def edit?
      index?
    end

    def create?
      index?
    end

    def update?
      index?
    end

    def destroy?
      index?
    end

    def permitted_attributes
      %i[description code] << {member_type_ids: []}
    end
  end
end
