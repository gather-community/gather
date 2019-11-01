# frozen_string_literal: true

require "csv"

module Meals
  # Imports meals from CSV.
  class CsvImporter
    BASIC_HEADERS = %i[served_at resources formula communities action].freeze
    REQUIRED_HEADERS = %i[served_at resources].freeze
    DB_ID_REGEX = /\A\d+\z/.freeze

    attr_accessor :file, :errors, :community, :user, :row_pointer, :row_action, :header_map, :current_meal

    def initialize(file, community:, user:)
      self.file = file
      self.errors = Hash.new { |h, k| h[k] = [] }
      self.community = community
      self.row_pointer = 0
      self.header_map = {}
      self.user = user
    end

    def import
      rows = CSV.new(file, converters: ->(f) { f&.strip }).read
      if rows.size < 2
        add_error("File is empty")
        return
      else
        ActiveRecord::Base.transaction do
          parse_rows(rows)
          errors.each { |k, v| errors.delete(k) if v.empty? } # Clear empties
          raise ActiveRecord::Rollback unless successful?
        end
      end
    end

    def successful?
      return @success if defined?(@success)
      @success = errors.values.none?(&:any?)
    end

    private

    def parse_rows(rows)
      rows.each do |row|
        self.row_pointer += 1
        self.row_action = :create
        next if row.empty?
        (parse_headers(row) ? next : break) if row_pointer == 1
        self.current_meal = Meal.new
        header_map.each do |col_index, attrib|
          parse_attrib(attrib, row[col_index])
        end
        next if current_row_errors?
        create_update_or_destroy
      end
    end

    def create_update_or_destroy
      meal = row_action == :create ? current_meal : find_matching_meal
      return unless meal
      return destroy(meal) if row_action == :destroy

      assign_meal_defaults(meal) if row_action == :create

      if row_action == :update
        # Currently not allowing updates to formula via CSV due to policy complications.
        meal.assign_attributes(
          current_meal.attributes.slice(:served_at, :resources, :communities, :assignments)
        )
      end
      meal.errors.full_messages.each { |e| add_error(e) } unless current_meal.save
    end

    def destroy(meal)
      meal.destroy
    rescue StandardError => error
      add_error("Error deleting meal #{meal.id}: '#{error}'")
    end

    def find_matching_meal
      candidates = Meals::MealPolicy::Scope.new(user, Meals::Meal).resolve
        .where(served_at: current_meal.served_at)
      meal = candidates.detect { |m| m.resources.to_set == current_meal.resources.to_set }
      return meal if meal.present?
      add_error("Could not find meal served at #{I18n.l(current_meal.served_at).gsub('  ', ' ')} at "\
        "locations: #{current_meal.resources.map(&:name).join(', ')}")
    end

    def parse_headers(row)
      scan_and_validate_headers(row)
      check_for_missing_headers
      errors.none?
    end

    def scan_and_validate_headers(row)
      bad_headers = []
      row.each_with_index do |cell, col_index|
        if (attrib = untranslate_header(cell) || role_from_header(cell))
          header_map[col_index] = attrib
        else
          bad_headers << cell
        end
      end
      add_error("Invalid column headers: #{bad_headers.join(', ')}") if bad_headers.any?
    end

    def check_for_missing_headers
      missing = REQUIRED_HEADERS - header_map.values
      return true if missing.none?
      names = missing.map { |h| translate_header(h) }.join(", ")
      add_error("Missing columns: #{names}")
    end

    # Looking up a header symbol based on the provided human-readable string.
    def untranslate_header(str)
      @untranslate_dict ||= BASIC_HEADERS.map { |h| [translate_header(h).downcase, h] }.to_h
      @untranslate_dict[str.downcase]
    end

    def translate_header(h)
      I18n.t("csv.headers.meals/meal.#{h}", default: :"csv.headers.common.#{h}")
    end

    def role_from_header(cell)
      scope = Meals::RolePolicy::Scope.new(user, Meals::Role).resolve.in_community(community).active
      if (match_data = cell.match(/\A#{I18n.t("csv.headers.meals/meal.role")}(\d+)\z/))
        scope.find_by(id: match_data[1])
      else
        scope.find_by(title: cell)
      end
    end

    def assign_meal_defaults(meal)
      meal.formula ||= Formula.default_for(community)
      meal.community = community
      meal.communities = Community.all if meal.communities.none?
      meal.creator = user
      meal.capacity = community.settings.meals.default_capacity
      meal.build_reservations
    end

    def parse_attrib(attrib, str)
      case attrib
      when :action, :served_at, :resources, :formula, :communities
        send("parse_#{attrib}", str)
      when Meals::Role
        parse_role(attrib, str)
      end
    end

    def parse_action(str)
      return :create if str.blank?
      return add_error("Invalid action: #{str}") unless %w[create update delete].include?(str.downcase)
      self.row_action = str.downcase.to_sym
    end

    def parse_served_at(str)
      return add_error("Date/time is required") if str.blank?
      current_meal.served_at = Time.zone.parse(str)
      raise ArgumentError if current_meal.served_at.nil?
    rescue ArgumentError, TypeError
      add_error("'#{str}' is not a valid date/time")
    end

    def parse_resources(str)
      return add_error("Resource(s) are required") if str.blank?
      current_meal.resources = str.split(/\s*;\s*/).map do |substr|
        find_resource(substr)
      end.compact
    end

    def parse_formula(str)
      return if str.blank?
      current_meal.formula = find_formula(str)
    end

    def parse_communities(str)
      return if str.blank?
      current_meal.communities = str.split(/\s*;\s*/).map do |substr|
        find_community(substr)
      end.compact
    end

    def parse_role(role, str)
      return if str.blank?
      str.split(/\s*;\s*/).each do |substr|
        next unless (user = find_user(substr))
        current_meal.assignments.build(role: role, user: user)
      end
    end

    def add_error(msg)
      errors[row_pointer] << msg
      nil
    end

    def current_row_errors?
      errors[row_pointer].any?
    end

    def find_resource(str)
      attrib = id?(str) ? :id : :name
      scope = Reservations::ResourcePolicy::Scope.new(user, Reservations::Resource).resolve
        .in_community(community).active
      scope.find_by(id: str) || scope.find_by("LOWER(name) = ?", str.downcase) ||
        add_error(I18n.t("csv.errors.meals/meal.resource.bad_#{attrib}", str: str))
    end

    def find_formula(str)
      attrib = id?(str) ? :id : :name
      scope = Meals::FormulaPolicy::Scope.new(user, Meals::Formula).resolve
        .in_community(community).active
      scope.find_by(id: str) || scope.find_by("LOWER(name) = ?", str.downcase) ||
        add_error(I18n.t("csv.errors.meals/meal.formula.bad_#{attrib}", str: str))
    end

    def find_community(str)
      attrib = id?(str) ? :id : :name
      strd = str.downcase
      scope = CommunityPolicy::Scope.new(user, Community).resolve
      scope.find_by(id: str) || scope.find_by("LOWER(name) = ? OR LOWER(abbrv) = ?", strd, strd) ||
        add_error(I18n.t("csv.errors.meals/meal.community.bad_#{attrib}", str: str))
    end

    def find_user(str)
      attrib = id?(str) ? :id : :name
      scope = UserPolicy::Scope.new(user, User).resolve.in_community(community).active
      scope.find_by(id: str) || scope.with_full_name(str).first ||
        add_error(I18n.t("csv.errors.meals/meal.user.bad_#{attrib}", str: str))
    end

    def id?(str)
      str.match?(DB_ID_REGEX)
    end
  end
end
