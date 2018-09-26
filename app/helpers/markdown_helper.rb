# frozen_string_literal: true

# Markdown is a minimalistic markup syntax
module MarkdownHelper
  def safe_render_markdown(str)
    renderer = Redcarpet::Markdown.new(Redcarpet::Render::HTML,
      autolink: true,
      space_after_headers: true,
      tables: true)
    sanitize(renderer.render(str))
  end
end
