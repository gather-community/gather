# frozen_string_literal: true

# == Schema Information
#
# Table name: meal_imports
#
#  id            :bigint           not null, primary key
#  errors_by_row :jsonb
#  status        :string           default("queued"), not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  cluster_id    :bigint           not null
#  community_id  :bigint           not null
#  user_id       :bigint           not null
#
# Indexes
#
#  index_meal_imports_on_cluster_id    (cluster_id)
#  index_meal_imports_on_community_id  (community_id)
#  index_meal_imports_on_user_id       (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (cluster_id => clusters.id)
#  fk_rails_...  (community_id => communities.id)
#  fk_rails_...  (user_id => users.id)
#
require "csv"

module Meals
  # Imports meals from CSV.
  class Import < ApplicationRecord
    include AttachmentFormable

    BASIC_HEADERS = %i[served_at calendars formula communities action id].freeze
    REQUIRED_HEADERS = %i[served_at calendars].freeze
    DB_ID_REGEX = /\A\d+\z/

    acts_as_tenant :cluster

    attr_accessor :row_pointer, :row_action, :header_map, :new_meal, :target_meal, :row_policy, :parsed_id

    belongs_to :community
    belongs_to :user

    has_one_attached :file

    accepts_attachment_via_form :file
    validates :file, presence: true, content_type: {in: %w[text/plain text/csv]}

    def import
      update!(status: "running")
      self.row_pointer = 0
      self.errors_by_row ||= {}
      process
      update!(status: "finished")
    end

    # crashed status indicates an unexpected error
    def crashed?
      status == "crashed"
    end

    def successful?
      complete? && !crashed? && error_free?
    end

    def complete?
      %w[finished crashed].include?(status)
    end

    def sorted_errors_by_row
      errors_by_row.keys.sort_by(&:to_i).map { |k| [k, errors_by_row[k]] }.to_h
    end

    private

    def process
      file.open do |file|
        # bom|utf-8 is needed to handle Excel-generated CSVs.
        rows = CSV.read(file.path, converters: ->(f) { f&.strip }, encoding: "bom|utf-8")
        if rows.size < 2
          add_error("File is empty")
        else
          ActiveRecord::Base.transaction do
            parse_rows(rows)
            errors_by_row.each { |k, v| errors_by_row.delete(k) if v.empty? } # Clear empties
            raise ActiveRecord::Rollback unless error_free?
          end
        end
      end
    end

    def error_free?
      return @error_free if defined?(@error_free)
      @error_free = errors_by_row.values.all?(&:empty?)
    end

    def parse_rows(rows)
      rows.each do |row|
        self.row_pointer += 1
        self.row_action = :create
        next if row.empty?
        (parse_headers(row) ? next : break) if row_pointer == 1
        self.new_meal = Meal.new(source_form: "import")
        header_map.each do |col_index, attrib|
          parse_attrib(attrib, row[col_index])
        end
        next if current_row_errors?
        create_update_or_destroy
      end
    end

    def create_update_or_destroy
      self.target_meal = (row_action == :create) ? new_meal : find_matching_meal
      return unless target_meal
      target_meal.community = community # May be redundant, needed for permission check
      self.row_policy = Meals::MealPolicy.new(user, target_meal)
      return add_error("Action not permitted (#{row_action})") unless row_policy.send("#{row_action}?")
      return destroy_target_meal if row_action == :destroy
      assign_defaults_to_new_meal
      copy_attribs_to_target_meal if row_action == :update
      unless target_meal.save
        target_meal.errors.each do |error|
          # We don't care about errors on the calendars collection b/c they are separate added
          # by the Meals::EventHandler so the error on :calendars is a duplicate.
          add_error(error.full_message) unless error.attribute == :calendars
        end
      end
    end

    def assign_defaults_to_new_meal
      new_meal.formula ||= Formula.default_for(community)
      new_meal.communities = Community.all if new_meal.communities.none?
      new_meal.creator = user
      new_meal.capacity = community.settings.meals.default_capacity
      new_meal.build_events
    end

    def copy_attribs_to_target_meal
      attribs = []
      attribs.concat(%i[served_at calendars]) if row_policy.change_date_loc?
      attribs.concat(%i[communities]) if row_policy.change_invites?
      attribs << :formula if row_policy.change_formula?
      attribs << :assignments if row_policy.change_workers?
      attribs.each { |attrib| target_meal.send("#{attrib}=", new_meal.send(attrib)) }
    end

    def destroy_target_meal
      target_meal.destroy
    rescue => error
      add_error("Error deleting meal #{target_meal.id}: '#{error}'")
    end

    def find_matching_meal
      scope = Meals::MealPolicy::Scope.new(user, Meals::Meal).resolve
      if parsed_id
        scope.find_by(id: parsed_id) || add_error("Could not find meal with ID '#{parsed_id}'")
      else
        candidates = scope.where(served_at: new_meal.served_at)
        meal = candidates.detect { |m| m.calendars.to_set == new_meal.calendars.to_set }
        return meal if meal.present?
        add_error("Could not find meal served at #{I18n.l(new_meal.served_at).gsub("  ", " ")} at " \
          "locations: #{new_meal.calendars.map(&:name).join(", ")}")
      end
    end

    def parse_headers(row)
      scan_and_validate_headers(row)
      check_for_missing_headers
      errors_by_row.none?
    end

    def scan_and_validate_headers(row)
      self.header_map = {}
      bad_headers = []
      row.each_with_index do |cell, col_index|
        if (attrib = untranslate_header(cell) || role_from_header(cell))
          header_map[col_index] = attrib
        else
          bad_headers << cell
        end
      end
      add_error("Invalid column headers: #{bad_headers.join(", ")}") if bad_headers.any?
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

    def translate_header(header)
      I18n.t("csv.headers.meals/meal.#{header}", default: :"csv.headers.common.#{header}")
    end

    def role_from_header(cell)
      scope = Meals::RolePolicy::Scope.new(user, Meals::Role).resolve.in_community(community).active
      if (match_data = cell.match(/\A#{I18n.t("csv.headers.meals/meal.role")}(\d+)\z/))
        scope.find_by(id: match_data[1])
      else
        scope.find_by(title: cell)
      end
    end

    def parse_attrib(attrib, str)
      case attrib
      when :action, :served_at, :calendars, :formula, :communities
        send("parse_#{attrib}", str)
      when :id
        self.parsed_id = str
      when Meals::Role
        parse_role(attrib, str)
      end
    end

    def parse_action(str)
      return :create if str.blank?
      return add_error("Invalid action: #{str}") unless %w[create update destroy].include?(str.downcase)
      self.row_action = str.downcase.to_sym
    end

    def parse_served_at(str)
      return add_error("Date/time is required") if str.blank?
      new_meal.served_at = Time.zone.parse(str)
      raise ArgumentError if new_meal.served_at.nil?
    rescue ArgumentError, TypeError
      add_error("'#{str}' is not a valid date/time")
    end

    def parse_calendars(str)
      return add_error("Calendar(s) are required") if str.blank?
      new_meal.calendars = str.split(/\s*;\s*/).map do |substr|
        find_calendar(substr)
      end.compact
    end

    def parse_formula(str)
      return if str.blank?
      new_meal.formula = find_formula(str)
    end

    def parse_communities(str)
      return if str.blank?
      new_meal.communities = str.split(/\s*;\s*/).map do |substr|
        find_community(substr)
      end.compact
    end

    def parse_role(role, str)
      return if str.blank?
      str.split(/\s*;\s*/).each do |substr|
        next unless (user = find_user(substr))
        new_meal.assignments.build(role: role, user: user)
      end
    end

    def add_error(msg)
      errors_by_row[row_pointer] ||= []
      errors_by_row[row_pointer] << msg
      nil
    end

    def current_row_errors?
      errors_by_row[row_pointer].present?
    end

    def find_calendar(str)
      attrib = id?(str) ? :id : :name

      # We don't need to restrict to the current community explicitly. The policy scope,
      # multi tenant system, and calendar protocols will take care of that if appropriate.
      scope = Calendars::CalendarPolicy::Scope.new(user, Calendars::Calendar).resolve.active

      scope.find_by(id: str) || scope.find_by("LOWER(name) = ?", str.downcase) ||
        add_error(I18n.t("csv.errors.meals/meal.calendar.bad_#{attrib}", str: str))
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
