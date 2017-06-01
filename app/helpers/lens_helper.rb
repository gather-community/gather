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
        html = lens.fields.map { |f| send("#{f}_field", f).try(:<<, " ") }
        html << clear_link unless lens.all_required?
        html.compact.reduce(:<<)
      end
    end

    private

    def clear_link
      if lens.optional_fields_blank?
        ""
      else
        link_to(icon_tag("times-circle") << " " << content_tag(:span, "Clear Filter"),
          request.path << "?" << lens.query_string_to_clear,
          class: "clear")
      end
    end

    def community_field(field)
      return nil unless multi_community?
      communities = load_communities_in_cluster
      field.options[:subdomain] = true unless field.options.key?(:subdomain)

      prompt = field.options[:required] ? "".html_safe : content_tag(:option, "All Communities", value: "all")

      selected = if lens[:community] == "all" || lens[:community].blank?
        nil
      elsif field.options[:subdomain]
        current_community.slug
      else
        lens[:community]
      end

      options = prompt << options_from_collection_for_select(communities, 'slug', 'name', selected)

      new_url = url_for(
        host: "' + this.value + '.#{Settings.url.host}",
        params: params.except(:action, :controller).merge(field.options[:required] ? {} : {community: "this"})
      )

      onchange = if field.options[:subdomain]
        "if (this.value == 'all') {
          this.name = 'community';
          this.form.submit();
        } else {
          window.location.href = '#{new_url}'
        }"
      else
        "this.form.submit();"
      end

      name = field.options[:subdomain] ? "" : "community"

      select_tag(name, options, class: "form-control", onchange: onchange, id: "community")
    end

    def user_field(field)
      selected_option_tag = if lens[:user].present?
        user = policy_scope(User).find(lens[:user])
        content_tag(:option, user.name, value: user.id, selected: "selected")
      else
        ""
      end

      select_tag("user", selected_option_tag,
        prompt: "All Users",
        class: "form-control",
        onchange: "this.form.submit();",
        data: {
          "select2-src" => "users",
          "select2-prompt" => t("select2_prompts.user"),
          "select2-variable-width" => "true",
          "select2-context" => "lens"
        }
      )
    end

    # Could end up with collisions here in future. Should refactor to scope this better.
    def time_field(field)
      opts = %w(past finalizable all)
      opts.delete("finalizable") if params[:action] == "jobs"
      opt_key = "simple_form.options.meal.time"
      select_tag("time",
        options_for_select(opts.map { |o| [I18n.t("#{opt_key}.#{o}"), o] }, lens[:time]),
        prompt: "Upcoming",
        class: "form-control",
        onchange: "this.form.submit();"
      )
    end

    def life_stage_field(field)
      opts = %w(adult child)
      opt_key = "simple_form.options.user.life_stage"
      select_tag("life_stage",
        options_for_select(opts.map { |o| [I18n.t("#{opt_key}.#{o}"), o] }, lens[:life_stage]),
        prompt: I18n.t("#{opt_key}.any"),
        class: "form-control",
        onchange: "this.form.submit();"
      )
    end

    def user_sort_field(field)
      opts = %w(unit)
      opt_key = "simple_form.options.user.sort"
      select_tag("user_sort",
        options_for_select(opts.map { |o| [I18n.t("#{opt_key}.#{o}"), o] }, lens[:user_sort]),
        prompt: I18n.t("#{opt_key}.name"),
        class: "form-control",
        onchange: "this.form.submit();"
      )
    end

    def search_field(field)
      text_field_tag("search", lens[:search], placeholder: "Search...", class: "form-control")
    end

    def method_missing(*args, &block)
      @template.send(*args, &block)
    end
  end
end
