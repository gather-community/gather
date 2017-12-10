module Wiki
  class PageDecorator < ApplicationDecorator
    delegate_all

    def formatted_content
      h.content_tag(:div, class: "wiki-content") do
        h.sanitize(render_markdown(linkify(h.wiki_show_attachments(content)).html_safe))
      end
    end

    def revision_info
      h.content_tag(:div, class: "wiki-page-revision-info") do
        h.t("wiki.revision_info", time: h.l(updated_at), user: updator.decorate.name_with_inactive)
      end
    end

    def show_action_link_set
      ActionLinkSet.new(
        ActionLink.new(object, :edit, icon: "pencil", path: h.wiki_page_edit_path(object)),
        ActionLink.new(object, :history, icon: "clock-o", path: h.wiki_page_history_path(object)),
        ActionLink.new(object, :destroy, icon: "trash", path: h.wiki_page_path(object),
          method: :delete, confirm: {title: title})
      )
    end

    def diff(old_ver, new_ver)
      h.sanitize(Diffy::Diff.new(old_ver.content, new_ver.content).to_s(:html))
    end

    def history(versions)
      h.render "wiki_page_history", page: self, versions: versions, with_form: versions.size > 1
    end

    private

    def linkify(str)
      str.gsub /\[\[
                  (?:([^\[\]\|]+)\|)?
                  ([^\[\]]+)
                 \]\]
                 (\w+)?/xu do |m|
        text = "#$2#$3"
        title, anchor = if $1 then $1.split('#', 2) else $2 end
        page = Wiki::Page.find_by(title: title) || Wiki::Page.new(path: CGI::escape(title))
        h.link_to(title, h.wiki_page_path(page) + (anchor ? "##{anchor}" : ""),
          class: page.new_record? ? "not-found" : nil)
      end.html_safe
    end

    def render_markdown(str)
      renderer.render(str)
    end

    def renderer
      @renderer ||= Redcarpet::Markdown.new(Redcarpet::Render::HTML,
        autolink: true,
        space_after_headers: true,
        tables: true
      )
    end
  end
end
