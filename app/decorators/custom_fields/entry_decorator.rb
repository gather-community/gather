# frozen_string_literal: true

module CustomFields
  class EntryDecorator < ApplicationDecorator
    delegate_all

    def formatted_value
      return nil if value.nil?

      case type
      when :boolean then I18n.t("custom_fields.boolean.#{value}")
      when :markdown then h.safe_render_markdown(value)
      when :text then h.simple_format(value)
      when :url then h.link_to(value, value)
      else value
      end
    end

    def sanitized_hint
      return nil if hint.nil?

      # Hints can contain user-generated HTML.
      Rails::Html::SafeListSanitizer.new.sanitize(hint).html_safe # rubocop:disable Rails/OutputSafety
    end
  end
end
