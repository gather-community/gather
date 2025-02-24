# frozen_string_literal: true

# For selecting community.
class CommunityLens < Lens::SelectLens
  param_name :community
  i18n_key "community_lens"

  def initialize(**args)
    super
    options[:subdomain] = true unless options.key?(:subdomain)
    self.communities = context.current_cluster.communities.by_name
  end

  def render
    context.multi_community? ? select_tag : nil
  end

  def selection
    if clearable? && (value == "all" || value.nil?)
      communities
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
    # Sort the current community to the top so it's the default if not clearable. Ensure sort is stable.
    self.communities = communities.sort_by.with_index { |c, i| context.current_community == c ? 0 : i + 1 }
    community_options = communities.map do |c|
      [c.name, c == context.current_community && clearable? ? "this" : c.slug]
    end
    (clearable? ? [:all] : []).concat(community_options)
  end

  def all?
    value == "all" || value.blank?
  end

  def select_input_name
    options[:subdomain] ? "" : "community"
  end

  def onchange
    if options[:subdomain]
      current_slug = context.current_community.slug
      params = route_params.except(:action, :controller).merge(clearable? ? {community: "this"} : {})
      host_with_port = [Settings.url.host, Settings.url.port].compact.join(":")
      "if (this.value == '') {
        this.name = 'community';
        this.form.submit();
      } else {
        let host = (this.value == 'this' ? '#{current_slug}' : this.value) + '.#{host_with_port}';
        window.location.href =
          '#{Settings.url.protocol}://' + host + '#{context.request.path}?#{params.to_query}';
      }"
    else
      "this.form.submit();"
    end
  end
end
