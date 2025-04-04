# frozen_string_literal: true

module GDrive
  module Migration
    # For filtering migration files based on status.
    class StatusLens < Lens::SelectLens
      param_name :status
      i18n_key "simple_form.options.gdrive_migration.status"

      protected

      def possible_options
        %i[any pending errored declined transferred copied ignored disappeared]
      end
    end
  end
end
