# frozen_string_literal: true

# For selecting community. Highly customized!
class CommunityLens < Lens::SelectLens
  param_name :community
  i18n_key "community_lens"

  def initialize(**args)
    super(**args)
    options[:subdomain] = true unless options.key?(:subdomain)
    self.communities = h.load_communities_in_cluster
  end

  def render
    context.multi_community? ? select_tag : nil
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

  def select_tag_id
    "community" # The default may be nil if the input name is blank.
  end

  def select_input_name
    options[:subdomain] ? "" : "community"
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
      params: route_params.except(:action, :controller)
        .merge(options[:required] ? {} : {community: "this"})
    )
  end

  def option_tags
    prompt_option_tag << h.options_from_collection_for_select(communities, "slug", "name", selected)
  end

  def prompt_option_tag
    if options[:required]
      "".html_safe
    else
      h.content_tag(:option, translate_option(:all), value: "all")
    end
  end
end
