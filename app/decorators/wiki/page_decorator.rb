# frozen_string_literal: true

module Wiki
  # Decorates wiki pages. Lots of key stuff happens here!
  class PageDecorator < ApplicationDecorator
    delegate_all

    attr_accessor :data_fetch_error

    # Sets data_fetch_error on first run if there is a problem fetching data
    def formatted_content
      return @formatted_content if defined?(@formatted_content)

      classes = ["wiki-content"]
      classes << "preview" if h.params[:preview]
      @formatted_content = h.tag.div(class: classes.join(" ")) do
        # iframe tags are useful for embedding and should be generally safe especially in closed communities.
        h.safe_render_markdown(process_data(linkify(content)), extra_allowed_tags: %w[iframe])
      end
    end

    # Tests Mustache syntax and returns any error encountered.
    def template_error
      # An empty hash should not trigger syntax errors. It just results in empty content.
      # A syntax error is only caused by invalid syntax!
      Mustache.render(content, {})
      nil
    rescue Mustache::Parser::SyntaxError
      format_mustache_error($ERROR_INFO)
    end

    def revision_info
      h.tag.span(class: "wiki-page-revision-info") do
        if updater
          h.t("wiki.revision_info", time: h.l(updated_at), user: updater.decorate.name_with_inactive)
        else
          h.t("wiki.revision_info_no_by", time: h.l(updated_at))
        end
      end
    end

    def footer_content
      bits = []
      sample_page = Wiki::Page.new(community: h.current_community)
      bits << h.link_to("Wiki Page Listing", h.all_wiki_pages_path) if h.policy(sample_page).all?
      bits << h.link_to("New Wiki Page", h.new_wiki_page_path) if h.policy(sample_page).create?
      bits << revision_info
      bits.reduce(&sep("&nbsp;&nbsp;&nbsp;"))
    end

    def show_action_link_set
      ActionLinkSet.new(
        ActionLink.new(object, :edit, icon: "pencil", path: h.edit_wiki_page_path(object)),
        ActionLink.new(object, :history, icon: "clock", path: h.history_wiki_page_path(object)),
        ActionLink.new(object, :destroy, icon: "trash", path: h.wiki_page_path(object),
                                         method: :delete, confirm: {title: title})
      )
    end

    def diff(old_ver, new_ver)
      h.sanitize(Diffy::Diff.new(old_ver.content, new_ver.content).to_s(:html))
    end

    def history(versions)
      h.render("history_table", page: self, versions: versions, with_form: versions.size > 1)
    end

    def data_fetch_error?
      data_fetch_error.present?
    end

    private

    def linkify(str)
      str.gsub(link_regex) do
        link(
          title: Regexp.last_match[1] || Regexp.last_match[2],
          display_name: Regexp.last_match[2] || Regexp.last_match[1]
        )
      end.html_safe # We can mark this as html_safe because we're using safe_render_markdown.
    end

    def link(title:, display_name:)
      link_class = nil
      if (page = Page.find_by(community: community, title: title))
        path = h.wiki_page_path(page)
      else
        link_class = "not-found"
        path = if can_create_page?
                 h.new_wiki_page_path(title: title)
               else
                 # We know this link will lead to a 404, but since the user doesn't have permissions
                 # to create a page, this is the most consistent UX.
                 h.wiki_page_path(slug: Page.reserved_slug(:notfound))
               end
      end
      h.link_to(display_name, path, class: link_class)
    end

    def link_regex
      /\[\[                 # The opening [[
        (?:([^\[\]|]+)\|)? # An optional first segment with pipe, not capturing pipe
        ([^\[\]]+)          # Another segment
        \]\]                # Closing ]]
        /x
    end

    # Processes mustache syntax in given string combined with data from data_source.
    # Sets data_fetch_error if any errors encountered.
    def process_data(str)
      if data_source.present?
        begin
          Mustache.render(str, JSON.parse(URI.open(data_source, &:read)))
        rescue SocketError
          self.data_fetch_error = I18n.t("activerecord.errors.models.wiki/page.data_fetch.socket_error")
          ""
        rescue OpenURI::HTTPError
          self.data_fetch_error = $ERROR_INFO.to_s
          ""
        rescue JSON::ParserError
          self.data_fetch_error = I18n.t("activerecord.errors.models.wiki/page.data_fetch.invalid_json")
          ""
        rescue Mustache::Parser::SyntaxError
          self.data_fetch_error = format_mustache_error($ERROR_INFO)
          ""
        end
      else
        str
      end
    end

    def format_mustache_error(error)
      details = if (m = error.to_s.match(/\A.+Line \d+/m))
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

    def can_create_page?
      h.policy(sample_page).create?
    end
  end
end
