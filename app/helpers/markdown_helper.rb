# Markdown is a minimalistic markup syntax
module MarkdownHelper
  def safe_render_markdown(str)
    renderer = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
    renderer.render(sanitize(str)).html_safe
  end
end
