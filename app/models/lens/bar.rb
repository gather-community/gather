# frozen_string_literal: true

module Lens
  # Handles generating HTML for the set bars on pages.
  class Bar
    attr_accessor :route_params, :context, :set

    def initialize(context:, set:)
      self.context = context
      self.set = set
    end

    def html(options = {})
      h.content_tag(:form, inner, class: "form-inline lens-bar hidden-print #{options[:position]}",
        data: {controller: "lens-bar"})
    end

    private

    def inner
      return @inner if @inner
      html = set.lenses.reject(&:floating?).map(&:render)
      html << link_to_clear
      @inner = html.compact.reduce(&h.sep(" "))
    end

    def h
      context.view_context
    end

    def link_to_clear
      if set.can_clear_lenses?
        h.link_to(h.icon_tag("times-circle") << " " << h.content_tag(:span, h.t("lens_bar.clear_filter")),
                  set.path_to_clear, class: "clear")
      else
        ""
      end
    end
  end
end
