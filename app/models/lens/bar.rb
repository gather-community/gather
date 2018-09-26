# Handles generating HTML for the set bars on pages.
module Lens
  class Bar
    attr_accessor :route_params, :context, :set, :options

    def initialize(context:, set:, options:)
      self.context = context
      self.set = set
      self.options = options
    end

    def to_s
      h.content_tag(:form, class: "form-inline lens-bar hidden-print #{options[:position]}") do
        html = set.lenses.reject(&:floating?).map(&:render)
        html << link_to_clear
        html.compact.reduce(&h.sep(" "))
      end
    end

    private

    def h
      context.view_context
    end

    def link_to_clear
      if set.optional_lenses_active?
        h.link_to(h.icon_tag("times-circle") << " " << h.content_tag(:span, "Clear Filter"),
          set.path_to_clear, class: "clear")
      else
        ""
      end
    end
  end
end
