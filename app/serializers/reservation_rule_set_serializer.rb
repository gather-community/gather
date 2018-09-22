# frozen_string_literal: true

# Serialize RuleSet for form.
class ReservationRuleSetSerializer < ApplicationSerializer
  attributes :fixed_start_time, :fixed_end_time, :access_level

  def initialize(rule_set, reserver_community:)
    super(rule_set)
    self.reserver_community = reserver_community
  end

  def access_level
    object.access_level(reserver_community)
  end

  def fixed_start_time
    object.fixed_start_time && I18n.l(object.fixed_start_time, format: :machine_readable)
  end

  def fixed_end_time
    object.fixed_end_time && I18n.l(object.fixed_end_time, format: :machine_readable)
  end

  private

  attr_accessor :reserver_community
end
