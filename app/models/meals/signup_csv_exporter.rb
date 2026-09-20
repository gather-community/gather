# frozen_string_literal: true

module Meals
  # Exports meal signups to CSV, one row per household signup per meal.
  class SignupCsvExporter < ::CsvExporter
    DinerCountColumn = Struct.new(:type)

    attr_accessor :community

    def initialize(initial_scope, policy:, community:)
      super(initial_scope, policy: policy)
      self.community = community
    end

    protected

    def klass
      Signup
    end

    def decorator_class
      SignupCsvDecorator
    end

    private

    def header_for(column)
      case column
      when DinerCountColumn then I18n.t("csv.headers.meals/signup.diner_count", type: column.type.name)
      else super
      end
    end

    def value_for(decorated, column)
      case column
      when DinerCountColumn then decorated.diner_count(column.type)
      else super
      end
    end

    # See Meals::MealCsvExporter#columns.
    def columns
      @columns ||= policy.exportable_attributes.flat_map do |attrib|
        (attrib == :diner_counts) ? types.map { |type| DinerCountColumn.new(type) } : attrib
      end
    end

    def types
      @types ||= Meals::Type.in_community(community).active.by_name.to_a
    end
  end
end
