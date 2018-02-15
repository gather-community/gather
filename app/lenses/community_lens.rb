class CommunityLens < ApplicationLens
  param_name :community

  def initialize(**args)
    super(**args)
    options[:subdomain] = true unless options.key?(:subdomain)
    self.communities = h.load_communities_in_cluster
  end

  def render
    return nil unless context.multi_community?
    h.select_tag(input_name, option_tags, class: "form-control",
      onchange: onchange, id: "community", "data-param-name": param_name)
  end

  private

  attr_accessor :communities

  def selected
    if !options[:required] && (value == "all" || value.blank?)
      nil
    elsif options[:subdomain] || value.blank?
      context.current_community.slug
    else
      value
    end
  end

  def onchange
    if options[:subdomain]
      "if (this.value == 'all') {
        this.name = 'community';
        this.form.submit();
      } else {
        window.location.href = '#{new_url}'
      }"
    else
      "this.form.submit();"
    end
  end

  def new_url
    h.url_for(
      host: "' + this.value + '.#{Settings.url.host}",
      params: route_params.except(:action, :controller).
        merge(options[:required] ? {} : {community: "this"})
    )
  end

  def option_tags
    prompt_option_tag << h.options_from_collection_for_select(communities, 'slug', 'name', selected)
  end

  def input_name
    options[:subdomain] ? "" : "community"
  end

  def prompt_option_tag
    if options[:required]
      "".html_safe
    else
      h.content_tag(:option, "All Communities", value: "all")
    end
  end
end
