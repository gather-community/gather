# frozen_string_literal: true

module Utils
  # Does markdown
  class Markdowner
    include ActionView::Helpers::SanitizeHelper
    include Singleton

    def render(str, extra_allowed_tags: [])
      return "" if str.blank?
      tags = Rails::Html::WhiteListSanitizer.allowed_tags.merge(extra_allowed_tags)
      attributes = Rails::Html::WhiteListSanitizer.allowed_attributes.merge(%w[target])
      renderer = Redcarpet::Render::HTML.new
      markdown = Redcarpet::Markdown.new(renderer, autolink: true, space_after_headers: true,
                                                   tables: true, strikethrough: true)
      sanitize(markdown.render(str), tags: tags, attributes: attributes)
    end
  end
end
