module FilterHelper
  def filter_bar(*fields)
    FilterBar.new(self, fields: fields, params: params, objects: {
      communities: @communities,
      user: @user
    }).to_html
  end

  class FilterBar
    attr_accessor :template, :fields, :params, :objects

    def initialize(template, fields:, params:, objects:)
      self.template = template
      self.fields = fields
      self.params = params
      self.objects = objects
    end

    def to_html
      content_tag(:form, class: "form-inline index-filter") do
        html = fields.map { |f| send("#{f}_filter") << " " }
        html << clear_link
        html.reduce(:<<)
      end
    end

    def clear_link
      if fields.any? { |k| params[k].present? }
        link_to(icon_tag("times-circle"), request.path, class: "clear")
      else
        ""
      end
    end

    def community_filter
      return "" if objects[:communities].size < 1

      select_tag("community",
        options_from_collection_for_select(objects[:communities], 'lc_abbrv', 'name', params[:community]),
        prompt: "All Communities",
        class: "form-control",
        onchange: "this.form.submit();"
      )
    end

    def user_filter
      selected_option_tag = if objects[:user]
        content_tag(:option, objects[:user].name, value: objects[:user].id, selected: "selected")
      else
        ""
      end

      select_tag("user", selected_option_tag,
        prompt: "All Users",
        class: "form-control",
        onchange: "this.form.submit();",
        data: { "select2-src" => "user" }
      )
    end

    def search_filter
      text_field_tag("search", params[:search], placeholder: "Search...", class: "form-control")
    end

    def method_missing(*args, &block)
      @template.send(*args, &block)
    end
  end
end
