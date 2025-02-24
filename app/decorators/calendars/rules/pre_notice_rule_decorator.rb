# frozen_string_literal: true

module Calendars
  module Rules
    class PreNoticeRuleDecorator < ApplicationDecorator
      delegate_all

      def alert_tag
        h.tag.div(class: "alert alert-info pre-notice", "data-kinds": kinds.to_json) do
          h.safe_render_markdown(value)
        end
      end
    end
  end
end
