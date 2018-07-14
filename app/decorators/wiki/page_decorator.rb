module Wiki
  class PageDecorator < ApplicationDecorator
    delegate_all

    attr_accessor :data_fetch_error

    # Sets data_fetch_error on first run if there is a problem fetching data
    def formatted_content
      return @formatted_content if defined?(@formatted_content)
      classes = ["wiki-content"]
      classes << "preview" if h.params[:preview]
      @formatted_content = h.content_tag(:div, class: classes.join(" ")) do
        h.safe_render_markdown(process_data(linkify(content)))
      end
    end

    # Tests Mustache syntax and returns any error encountered.
    def template_error
      begin
        # An empty hash should not trigger syntax errors. It just results in empty content.
        # A syntax error is only caused by invalid syntax!
        Mustache.render(content, {})
        nil
      rescue Mustache::Parser::SyntaxError
        format_mustache_error($!)
      end
    end

    def revision_info
      h.content_tag(:span, class: "wiki-page-revision-info") do
        h.t("wiki.revision_info", time: h.l(updated_at), user: updator.decorate.name_with_inactive)
      end
    end

    def show_action_link_set
      ActionLinkSet.new(
        ActionLink.new(object, :edit, icon: "pencil", path: h.edit_wiki_page_path(object)),
        ActionLink.new(object, :history, icon: "clock-o", path: h.history_wiki_page_path(object)),
        ActionLink.new(object, :destroy, icon: "trash", path: h.wiki_page_path(object),
          method: :delete, confirm: {title: title})
      )
    end

    def diff(old_ver, new_ver)
      h.sanitize(Diffy::Diff.new(old_ver.content, new_ver.content).to_s(:html))
    end

    def history(versions)
      h.render "history_table", page: self, versions: versions, with_form: versions.size > 1
    end

    def data_fetch_error?
      data_fetch_error.present?
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
        link_class = nil
        if page = Page.find_by(community: community, title: title)
          path = h.wiki_page_path(page) + (anchor ? "##{anchor}" : "")
        else
          link_class = "not-found"
          if h.policy(sample_page).create?
            path = h.new_wiki_page_path(title: title)
          else
            # We know this link will lead to a 404, but since the user doesn't have permissions
            # to create a page, this is the most consistent UX.
            path = h.wiki_page_path(slug: Page.reserved_slug(:notfound))
          end
        end
        h.link_to(title, path, class: link_class)
      end.html_safe
    end

    # Processes mustache syntax in given string combined with data from data_source.
    # Sets data_fetch_error if any errors encountered.
    def process_data(str)
      if data_source.present?
        begin
          Mustache.render(str, JSON.parse(Kernel.open(data_source, &:read)))
        rescue SocketError
          self.data_fetch_error = I18n.t("activerecord.errors.models.wiki/page.data_fetch.socket_error")
          ""
        rescue OpenURI::HTTPError
          self.data_fetch_error = $!.to_s
          ""
        rescue JSON::ParserError
          self.data_fetch_error = I18n.t("activerecord.errors.models.wiki/page.data_fetch.invalid_json")
          ""
        rescue Mustache::Parser::SyntaxError
          self.data_fetch_error = format_mustache_error($!)
          ""
        end
      else
        str
      end
    end

    def format_mustache_error(error)
      details = if m = error.to_s.match(/\A.+Line \d+/m)
        m[0]
      else
        error.to_s.gsub(/\s*\^\s*\z/m, "")
      end
      I18n.t("activerecord.errors.models.wiki/page.data_fetch.template_error",
        details: details.gsub("\n", ", ").gsub(/\s\s+/, " "))
    end

    def sample_page
      Page.new(community: community)
    end
  end
end
