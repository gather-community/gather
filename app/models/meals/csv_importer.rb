# frozen_string_literal: true

require "csv"

module Meals
  # Imports meals from CSV.
  class CsvImporter
    BASIC_HEADERS = %i[served_at resources formula communities].freeze
    DB_ID_REGEX = /\A\d+\z/.freeze

    attr_accessor :file, :errors, :community, :user, :row_pointer, :header_map, :current_meal

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
        next if row.empty?
        (parse_headers(row) ? next : break) if row_pointer == 1
        self.current_meal = Meal.new
        header_map.each do |col_index, attrib|
          parse_attrib(attrib, row[col_index])
        end
        next if current_row_errors?
        assign_meal_defaults
        current_meal.errors.full_messages.each { |e| add_error(e) } unless current_meal.save
      end
    end

    def assign_meal_defaults
      current_meal.formula ||= Formula.default_for(community)
      current_meal.community = community
      current_meal.communities = Community.all if current_meal.communities.none?
      current_meal.creator = user
      current_meal.capacity = community.settings.meals.default_capacity
      current_meal.build_reservations
    end

    def parse_headers(row)
      bad_headers = []
      row.each_with_index do |cell, col_index|
        if (attrib = untranslate_header(cell) || role_from_header(cell))
          header_map[col_index] = attrib
        else
          bad_headers << cell
        end
      end
      return true if bad_headers.empty?
      add_error("Invalid column headers: #{bad_headers.join(', ')}")
      false
    end

    # Looking up a header symbol based on the provided human-readable string.
    def untranslate_header(str)
      (@untranslate_dict ||= BASIC_HEADERS.map { |h| [I18n.t("csv.headers.meals/meal.#{h}"), h] }.to_h)[str]
    end

    def role_from_header(cell)
      if (match_data = cell.match(/\A#{I18n.t("csv.headers.meals/meal.role")}(\d+)\z/))
        Role.in_community(community).active.find_by(id: match_data[1])
      else
        Role.in_community(community).active.find_by(title: cell)
      end
    end

    def parse_attrib(attrib, str)
      case attrib
      when :served_at, :resources, :formula, :communities
        send("parse_#{attrib}", str)
      when Meals::Role
        parse_role(attrib, str)
      end
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
      col = id?(str) ? :id : :name
      Reservations::Resource.in_community(community).active.find_by(col => str) ||
        add_error(I18n.t("csv.errors.meals/meal.resource.bad_#{col}", str: str))
    end

    def find_formula(str)
      col = id?(str) ? :id : :name
      Meals::Formula.in_community(community).active.find_by(col => str) ||
        add_error(I18n.t("csv.errors.meals/meal.formula.bad_#{col}", str: str))
    end

    def find_community(str)
      col = id?(str) ? :id : :name
      Community.find_by(col => str) || Community.find_by(abbrv: str) ||
        add_error(I18n.t("csv.errors.meals/meal.community.bad_#{col}", str: str))
    end

    def find_user(str)
      col = id?(str) ? :id : :name
      scope = User.in_community(community).active
      (col == :id ? scope.find_by(id: str) : scope.with_full_name(str).first) ||
        add_error(I18n.t("csv.errors.meals/meal.user.bad_#{col}", str: str))
    end

    def id?(str)
      str.match?(DB_ID_REGEX)
    end
  end
end
