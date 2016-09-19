module LensHelper
  def lens_bar(options = {})
    LensBar.new(self, lens: lens, options: options).to_html
  end

  class LensBar
    attr_accessor :template, :lens, :options

    def initialize(template, lens:, options:)
      self.template = template
      self.lens = lens
      self.options = options
    end

    def to_html
      content_tag(:form, class: "form-inline lens-bar") do
        html = lens.fields.map { |f| send("#{f}_field") << " " }
        html << clear_link unless options[:required]
        html.reduce(:<<)
      end
    end

    private

    def clear_link
      if lens.blank?
        ""
      else
        link_to(icon_tag("times-circle"),
          request.path << "?" << lens.fields.map { |f| "#{f}=" }.join("&"),
          class: "clear")
      end
    end

    def community_field
      communities = Community.by_name
      return "" if communities.size < 1

      select_tag("community",
        options_from_collection_for_select(communities, 'lc_abbrv', 'name', lens[:community]),
        prompt: options[:required] ? nil : "All Communities",
        class: "form-control",
        onchange: "this.form.submit();"
      )
    end

    def user_field
      selected_option_tag = if lens[:user].present?
        user = User.find(lens[:user])
        content_tag(:option, user.name, value: user.id, selected: "selected")
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

    # Could end up with collisions here in future. Should refactor to scope this better.
    def time_field
      opts = %w(past finalizable all)
      opt_key = "simple_form.options.meal.time"
      select_tag("time",
        options_for_select(opts.map { |o| [I18n.t("#{opt_key}.#{o}"), o] }, lens[:time]),
        prompt: "Upcoming",
        class: "form-control",
        onchange: "this.form.submit();"
      )
    end

    def search_field
      text_field_tag("search", lens[:search], placeholder: "Search...", class: "form-control")
    end

    def method_missing(*args, &block)
      @template.send(*args, &block)
    end
  end
end
