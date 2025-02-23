# frozen_string_literal: true

module Calendars
  class ProtocolDecorator < ApplicationDecorator
    delegate_all

    def defined_rules
      rules = Rules::Rule::NAMES
        .reject { |n| self[n].nil? }
        .map { |n| safe_str << "#{t_rule_name(n)}: " << h.tag.strong(rule_value(n)) }
      h.safe_join(rules, h.tag(:br))
    end

    def calendar_names
      general? ? t("common.all") : calendars.map(&:name).join(", ")
    end

    def edit_action_link_set
      ActionLinkSet.new(
        ActionLink.new(object, :destroy, icon: "trash", path: h.calendars_protocol_path(object),
                                         method: :delete, confirm: {name: name})
      )
    end

    private

    def t_rule_name(rule_name)
      h.t("activerecord.attributes.calendars/protocol.#{rule_name}")
    end

    def rule_value(rule_name)
      val = self[rule_name]
      case rule_name
      when :pre_notice then h.truncate(val, length: 32, separator: " ")
      when :fixed_start_time, :fixed_end_time then h.l(val, format: :time_only).strip
      when :other_communities then h.t("simple_form.options.calendars_protocol.other_communities.#{val}")
      when :requires_kind then h.t("common.yes")
      when :max_lead_days, :max_days_per_year, :max_length_minutes, :max_minutes_per_year
        duration_rule_value(rule_name, val)
      end
    end

    def duration_rule_value(rule_name, val)
      key = case rule_name
            when :max_lead_days, :max_days_per_year then "days"
            else "mins"
            end
      h.t("calendars/protocol.durations.#{key}", count: val, formatted: h.number_with_delimiter(val))
    end
  end
end
