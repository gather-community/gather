# frozen_string_literal: true

module Meals
  # Exports a collection of meals to CSV.
  #
  # The leading columns match the format read by Meals::Import, so an exported file can be edited
  # and re-uploaded. The remaining columns (menu, status, signup totals, costs) are read-only;
  # Import ignores them (see Meals::Import::EXPORT_ONLY_HEADERS).
  class MealCsvExporter < ::CsvExporter
    # Wrappers distinguishing the two kinds of per-Meals::Type column from each other.
    DinerCountColumn = Struct.new(:type)
    TypePriceColumn = Struct.new(:type)

    attr_accessor :community

    def initialize(initial_scope, policy:, community:)
      super(initial_scope, policy: policy)
      self.community = community
    end

    protected

    def klass
      Meal
    end

    def decorator_class
      MealCsvDecorator
    end

    def scope(initial_scope)
      initial_scope.includes(:formula, :calendars, :communities, {assignments: %i[role user]},
        {signups: {parts: :type}}, {cost: [:reimbursee, {parts: :type}]})
    end

    private

    def header_for(column)
      case column
      when Meals::Role then column.title # Exact title, so Import#role_from_header can resolve it.
      when DinerCountColumn then I18n.t("csv.headers.meals/meal.diner_count", type: column.type.name)
      when TypePriceColumn then I18n.t("csv.headers.meals/meal.type_price", type: column.type.name)
      else super
      end
    end

    def value_for(decorated, column)
      case column
      when Meals::Role then decorated.workers_for_role(column)
      when DinerCountColumn then decorated.diner_count(column.type)
      when TypePriceColumn then decorated.type_price(column.type)
      else super
      end
    end

    # Expands the sentinels returned by Meals::MealPolicy#exportable_attributes into one column
    # per active role/type.
    def columns
      @columns ||= policy.exportable_attributes.flat_map do |attrib|
        case attrib
        when :roles then roles
        when :diner_counts then types.map { |type| DinerCountColumn.new(type) }
        when :type_prices then types.map { |type| TypePriceColumn.new(type) }
        else attrib
        end
      end
    end

    # Restricted to active roles because those are the only ones Import#role_from_header resolves
    # by title.
    def roles
      @roles ||= Meals::Role.in_community(community).active.by_title.to_a
    end

    def types
      @types ||= Meals::Type.in_community(community).active.by_name.to_a
    end
  end
end
