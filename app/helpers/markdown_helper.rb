# frozen_string_literal: true

module MarkdownHelper
  def safe_render_markdown(str, **options)
    Utils::Markdowner.instance.render(str, **options)
  end
end
