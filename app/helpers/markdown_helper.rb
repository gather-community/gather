# frozen_string_literal: true

module MarkdownHelper
  def safe_render_markdown(str, **)
    Utils::Markdowner.instance.render(str, **)
  end
end
