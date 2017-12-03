module Wiki
  class PageDecorator < ApplicationDecorator
    delegate_all

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

    protected

    # def action_link_icon(action)
    #   case action
    #   when :all then "list"
    #   when :show then "file-o"
    #   when :new then "plus"
    #   when :edit then "pencil"
    #   when :history then "clock"
    #   when :destroy then "trash"
    #   end
    # end

    # def action_link_path(action)
    #   case action
    #   when :all then wiki_all_path
    #   when :show then wiki_page_path(object)
    #   when :new then new_wiki_page_path
    #   when :edit then edit_wiki_page_path(object)
    #   when :history then history_wiki_page_path(object)
    #   when :destroy then wiki_page_path(object)
    #   end
    # end
  end
end
