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
      form_options = {class: "form-inline lens-bar hidden-print #{options[:position]}"}
      form_options[:action] = set.form_action if set.form_action
      h.content_tag(:form, inner, form_options)
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
        h.link_to(h.icon_tag("times-circle") << " " << h.content_tag(:span, "Clear Filter"),
                  set.path_to_clear, class: "clear")
      else
        ""
      end
    end
  end
end
