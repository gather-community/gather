# frozen_string_literal: true

module Work
  # Finds or constructs MealJobSyncSetting objects for all formulas/roles.
  class MealJobSyncSettingCollection
    include ActiveModel::Model

    attr_accessor :period

    def settings_by_formula
      return @settings_by_formula if defined?(@settings_by_formula)
      @settings_by_formula = {}
      formulas = Meals::Formula.in_community(period.community).includes(:roles).by_name
      formulas.each do |formula|
        @settings_by_formula[formula] = []
        formula.roles.each do |role|
          @settings_by_formula[formula] << find_or_init_setting_for(formula, role)
        end
        legacy_roles_for(formula).each do |role|
          @settings_by_formula[formula] << find_or_init_setting_for(formula, role, legacy: true)
        end
      end
      @settings_by_formula
    end

    private

    def find_or_init_setting_for(formula, role, legacy: false)
      setting = lookup_table.dig(formula, role)
      setting ||= period.meal_job_sync_settings.build(formula: formula, role: role, selected: false)
      setting.legacy = legacy
      setting
    end

    def legacy_roles_for(formula)
      settings_roles = lookup_table[formula]&.keys || []
      settings_roles - formula.roles
    end

    def lookup_table
      return @lookup_table if defined?(@lookup_table)
      @lookup_table = period.meal_job_sync_settings.group_by(&:formula)
      @lookup_table.each { |formula, settings| @lookup_table[formula] = settings.index_by(&:role) }
      @lookup_table
    end
  end
end
