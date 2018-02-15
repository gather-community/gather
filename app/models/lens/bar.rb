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
        html = set.lenses.map(&:render)
        html << clear_link unless set.all_required?
        html.compact.reduce(&h.sep(" "))
      end
    end

    private

    def h
      context.view_context
    end

    def clear_link
      if set.optional_lenses_blank?
        ""
      else
        h.link_to(h.icon_tag("times-circle") << " " << h.content_tag(:span, "Clear Filter"),
          context.request.path << "?" << set.query_string_to_clear,
          class: "clear")
      end
    end
  end
end
