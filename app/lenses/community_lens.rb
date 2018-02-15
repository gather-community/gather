class CommunityLens < ApplicationLens
  param_name :community

  def render
    return nil unless context.multi_community?
    communities = h.load_communities_in_cluster
    options[:subdomain] = true unless options.key?(:subdomain)

    prompt = if options[:required]
      "".html_safe
    else
      h.content_tag(:option, "All Communities", value: "all")
    end

    selected = if !options[:required] && (value == "all" || value.blank?)
      nil
    elsif options[:subdomain] || value.blank?
      context.current_community.slug
    else
      value
    end

    option_tags = prompt << h.options_from_collection_for_select(communities, 'slug', 'name', selected)

    new_url = h.url_for(
      host: "' + this.value + '.#{Settings.url.host}",
      params: route_params.except(:action, :controller).
        merge(options[:required] ? {} : {community: "this"})
    )

    onchange = if options[:subdomain]
      "if (this.value == 'all') {
        this.name = 'community';
        this.form.submit();
      } else {
        window.location.href = '#{new_url}'
      }"
    else
      "this.form.submit();"
    end

    name = options[:subdomain] ? "" : "community"

    h.select_tag(name, option_tags, class: "form-control", onchange: onchange, id: "community")
  end
end
