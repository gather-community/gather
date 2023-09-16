# frozen_string_literal: true

module GDrive
  module Migration
    # For filtering migration files based on owner.
    class OwnerLens < Lens::SelectLens
      param_name :owner
      i18n_key "simple_form.options.gdrive_migration.owner"

      protected

      def possible_options
        [:any].concat(options[:owners].map { |o| OpenStruct.new(id: o, name: o) })
      end
    end
  end
end
