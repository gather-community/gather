# frozen_string_literal: true

# Markdown is a minimalistic markup syntax
module MarkdownHelper
  def safe_render_markdown(str, extra_allowed_tags: [])
    return "" if str.blank?
    allowed_tags = Rails::Html::WhiteListSanitizer.allowed_tags + extra_allowed_tags
    renderer = Redcarpet::Markdown.new(Redcarpet::Render::HTML,
      autolink: true,
      space_after_headers: true,
      tables: true)
    sanitize(renderer.render(str), tags: allowed_tags)
  end
end
