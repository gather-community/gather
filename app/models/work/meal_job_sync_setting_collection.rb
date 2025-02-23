# frozen_string_literal: true

module Work
  # Finds or constructs MealJobSyncSetting objects for all formulas/roles.
  class MealJobSyncSettingCollection
    include ActiveModel::Model

    attr_accessor :period

    def settings_by_formula
      return @settings_by_formula if defined?(@settings_by_formula)

      @settings_by_formula = {}
      active_formulas = Meals::Formula.in_community(period.community).includes(:roles).active.by_name
      add_settings_for_formulas(active_formulas, legacy: false)
      add_settings_for_formulas(lookup_table.keys - active_formulas, legacy: true)
      @settings_by_formula
    end

    private

    def add_settings_for_formulas(formulas, legacy:)
      formulas.each do |formula|
        @settings_by_formula[formula] = []
        active_roles = formula.roles.active
        active_roles.each do |role|
          @settings_by_formula[formula] << find_or_init_setting_for(formula, role, legacy: legacy)
        end
        legacy_roles_for(formula, active_roles).each do |role|
          @settings_by_formula[formula] << find_or_init_setting_for(formula, role, legacy: true)
        end
      end
    end

    def find_or_init_setting_for(formula, role, legacy: false)
      setting = lookup_table.dig(formula, role)
      setting ||= period.meal_job_sync_settings.build(formula: formula, role: role, selected: false)
      setting.legacy = legacy
      setting
    end

    def legacy_roles_for(formula, active_roles)
      settings_roles = lookup_table[formula]&.keys || []
      settings_roles - active_roles
    end

    def lookup_table
      return @lookup_table if defined?(@lookup_table)

      @lookup_table = period.meal_job_sync_settings.group_by(&:formula)
      @lookup_table.each { |formula, settings| @lookup_table[formula] = settings.index_by(&:role) }
      @lookup_table
    end
  end
end
