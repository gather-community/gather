# frozen_string_literal: true

module Meals
  # Decorates Meal for CSV export.
  #
  # The first several columns are deliberately formatted to match what Meals::Import expects, so
  # that an exported file can be edited and re-uploaded. See Meals::MealCsvExporter.
  class MealCsvDecorator < MealDecorator
    include CsvDecorable

    SEPARATOR = "; "

    def served_at
      csv_localize(object.served_at)
    end

    def calendars
      object.calendars.map(&:name).join(SEPARATOR).presence
    end

    def formula
      object.formula&.name
    end

    def communities
      object.communities.map(&:name).join(SEPARATOR).presence
    end

    # An exported file also carries the ID column, so Meals::Import matches on primary key.
    # Defaulting to update (rather than leaving this blank, which import reads as create) means a
    # re-upload of an unedited export is a no-op instead of duplicating every meal.
    def action
      "update"
    end

    def workers_for_role(role)
      assignments = object.assignments_by_role[role] || []
      # Deliberately not User#name, which appends " (Inactive)" and so wouldn't re-import.
      assignments.map { |a| "#{a.user.first_name} #{a.user.last_name}" }.join(SEPARATOR).presence
    end

    def allergens
      return "None" if object.no_allergens?
      object.allergens.join(SEPARATOR).presence
    end

    def diner_count(type)
      signup_totals_by_type_id[type.id]
    end

    def ingredient_cost
      csv_currency(object.cost&.ingredient_cost)
    end

    def pantry_cost
      csv_currency(object.cost&.pantry_cost)
    end

    def total_cost
      csv_currency(object.cost&.total_cost)
    end

    def payment_method
      object.cost&.payment_method
    end

    def reimbursee
      object.cost&.reimbursee&.name
    end

    # Blank unless the meal is finalized, since that's when per-type prices get snapshotted.
    def type_price(type)
      csv_currency(cost_part_values_by_type_id[type.id])
    end

    private

    # Meal#signup_totals and Cost#parts_by_type are keyed by Meals::Type instances loaded via the
    # meal, while the exporter's types are loaded separately. Re-keying by ID avoids relying on
    # ActiveRecord's #hash/#eql? for the lookup.
    def signup_totals_by_type_id
      @signup_totals_by_type_id ||= object.signup_totals.transform_keys(&:id)
    end

    def cost_part_values_by_type_id
      @cost_part_values_by_type_id ||=
        (object.cost&.parts || []).to_h { |part| [part.type_id, part.value] }
    end
  end
end
