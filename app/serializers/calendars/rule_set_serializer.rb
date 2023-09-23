# frozen_string_literal: true

# Serialize RuleSet for form.
module Calendars
  class RuleSetSerializer < ApplicationSerializer
    attributes :fixed_start_time, :fixed_end_time, :access_level

    def initialize(rule_set, options)
      super(rule_set)
      self.creator_temp_community = options[:creator_temp_community]
    end

    def access_level
      object.access_level(creator_temp_community)
    end

    def fixed_start_time
      object.fixed_start_time&.to_s
    end

    def fixed_end_time
      object.fixed_end_time&.to_s
    end

    private

    attr_accessor :creator_temp_community
  end
end
