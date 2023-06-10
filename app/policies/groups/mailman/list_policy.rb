# frozen_string_literal: true

module Groups
  module Mailman
    class ListPolicy < ApplicationPolicy
      alias_method :list, :record

      def edit?
        active? && list.group && GroupPolicy.new(user, list.group).appropriate_admin?
      end

      def edit_name?
        edit? && list.new_record?
      end
    end
  end
end
