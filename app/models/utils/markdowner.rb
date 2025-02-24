# frozen_string_literal: true

module Utils
  # Does markdown
  class Markdowner
    include ActionView::Helpers::SanitizeHelper
    include Singleton

    def render(str, extra_allowed_tags: [])
      return "" if str.blank?

      table_tags = %w[table thead tbody tfoot tr th td]
      tags = Rails::Html::SafeListSanitizer.allowed_tags + extra_allowed_tags + table_tags
      attributes = Rails::Html::SafeListSanitizer.allowed_attributes + %w[target]
      renderer = Redcarpet::Render::HTML.new(hard_wrap: true)
      markdown = Redcarpet::Markdown.new(renderer, autolink: true, space_after_headers: true,
                                                   tables: true, strikethrough: true)
      sanitize(markdown.render(str), tags: tags, attributes: attributes)
    end
  end
end
