# frozen_string_literal: true

# For selecting community.
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

  def selection
    if !options[:required] && (value == "all" || value.nil?)
      context.current_cluster.communities
    elsif options[:subdomain] || value.nil? || value == "this"
      context.current_community
    elsif value.match(/\A\d+\z/) # Legacy link support
      Community.find(value)
    else
      Community.find_by(slug: value)
    end
  end

  private

  attr_accessor :communities

  def possible_options
    # Sort the current community to the top so it's the default if not clearable
    community_options = communities.sort_by { |c| context.current_community == c ? 0 : 1 }.map do |c|
      [c.name, c == context.current_community && !options[:required] ? "this" : c.slug]
    end
    (!options[:required] ? [:all] : []).concat(community_options)
  end

  def all?
    value == "all" || value.blank?
  end

  def select_input_name
    options[:subdomain] ? "" : "community"
  end

  def onchange
    if options[:subdomain]
      "if (this.value == '') {
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
end
