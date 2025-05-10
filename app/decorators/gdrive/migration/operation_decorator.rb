# frozen_string_literal: true

module GDrive
  module Migration
    class OperationDecorator < ApplicationDecorator
      delegate_all

      def show_action_link_set
        ActionLinkSet.new(
          ActionLink.new(object, :rescan, icon: "refresh", path: h.rescan_gdrive_migration_operation_path(object),
            method: :post),
          ActionLink.new(object, :edit, icon: "pencil", path: h.edit_gdrive_migration_operation_path(object)),
          ActionLink.new(object, :destroy, icon: "trash", path: h.gdrive_migration_operation_path(object),
            method: :delete, confirm: true)
        )
      end
    end
  end
end