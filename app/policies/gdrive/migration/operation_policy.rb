# frozen_string_literal: true

module GDrive
  module Migration
    class OperationPolicy < ApplicationPolicy
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

      def rescan?
        active_admin?
      end

      def update?
        active_admin?
      end

      def destroy?
        active_admin?
      end

      def permitted_attributes(action)
        if action.to_sym == :create
          %i[contact_email contact_name dest_folder_id src_folder_id]
        else
          %i[contact_email contact_name]
        end
      end
    end
  end
end
