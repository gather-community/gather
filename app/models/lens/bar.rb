# Handles generating HTML for the set bars on pages.
module Lens
  class Bar
    attr_accessor :route_params, :context, :set, :options

    def initialize(context:, set:, options:)
      self.context = context
      self.set = set
      self.options = options

      # This is ok because params are never used in Lens to do mass assignments.
      self.route_params = context.params.dup.permit!
    end

    def to_s
      h.content_tag(:form, class: "form-inline lens-bar hidden-print #{options[:position]}") do
        html = set.lenses.map { |f| send("#{f}_field", f).try(:<<, " ") }
        html << clear_link unless set.all_required?
        html.compact.reduce(:<<)
      end
    end

    private

    def h
      context.view_context
    end

    def clear_link
      if set.optional_lenses_blank?
        ""
      else
        h.link_to(h.icon_tag("times-circle") << " " << h.content_tag(:span, "Clear Filter"),
          context.request.path << "?" << set.query_string_to_clear,
          class: "clear")
      end
    end

    def community_field(field)
      return nil unless context.multi_community?
      communities = h.load_communities_in_cluster
      field.options[:subdomain] = true unless field.options.key?(:subdomain)

      prompt = if field.options[:required]
        "".html_safe
      else
        h.content_tag(:option, "All Communities", value: "all")
      end

      selected = if !field.options[:required] && (set[:community] == "all" || set[:community].blank?)
        nil
      elsif field.options[:subdomain] || set[:community].blank?
        context.current_community.slug
      else
        set[:community]
      end

      options = prompt << h.options_from_collection_for_select(communities, 'slug', 'name', selected)

      new_url = h.url_for(
        host: "' + this.value + '.#{Settings.url.host}",
        params: route_params.except(:action, :controller).
          merge(field.options[:required] ? {} : {community: "this"})
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

      h.select_tag(name, options, class: "form-control", onchange: onchange, id: "community")
    end

    def user_field(field)
      selected_option_tag = if set[:user].present?
        user = context.policy_scope(User).find(set[:user])
        h.content_tag(:option, user.name, value: user.id, selected: "selected")
      else
        ""
      end

      h.select_tag("user", selected_option_tag,
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
      opts.delete("finalizable") if route_params[:action] == "jobs"
      opt_key = "simple_form.options.meal.time"
      h.select_tag("time",
        h.options_for_select(opts.map { |o| [I18n.t("#{opt_key}.#{o}"), o] }, set[:time]),
        prompt: "Upcoming",
        class: "form-control",
        onchange: "this.form.submit();"
      )
    end

    def life_stage_field(field)
      opts = %w(adult child)
      opt_key = "simple_form.options.user.life_stage"
      h.select_tag("life_stage",
        h.options_for_select(opts.map { |o| [I18n.t("#{opt_key}.#{o}"), o] }, set[:life_stage]),
        prompt: I18n.t("#{opt_key}.any"),
        class: "form-control",
        onchange: "this.form.submit();"
      )
    end

    def user_sort_field(field)
      opts = %w(unit)
      opt_key = "simple_form.options.user.sort"
      h.select_tag("user_sort",
        h.options_for_select(opts.map { |o| [I18n.t("#{opt_key}.#{o}"), o] }, set[:user_sort]),
        prompt: I18n.t("#{opt_key}.name"),
        class: "form-control",
        onchange: "this.form.submit();"
      )
    end

    def user_view_field(field)
      opts = %w(table)
      opts << "tableall" if context.policy(h.sample_user).show_inactive?
      opt_key = "simple_form.options.user.view"
      h.select_tag("user_view",
        h.options_for_select(opts.map { |o| [I18n.t("#{opt_key}.#{o}"), o] }, set[:user_view]),
        prompt: I18n.t("#{opt_key}.album"),
        class: "form-control",
        onchange: "this.form.submit();"
      )
    end

    def search_field(field)
      h.text_field_tag("search", set[:search], placeholder: "Search...", class: "form-control")
    end
  end
end
