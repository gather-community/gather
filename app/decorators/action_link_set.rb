class ActionLinkSet < ApplicationDecorator
  attr_accessor :links_by_action, :actions

  def initialize(*links)
    self.links_by_action = links.index_by(&:action)
    self.actions = links_by_action.keys
  end

  def render(**options)
    options[:except] = Array.wrap(options[:except] || [])
    to_show = actions - options[:except]
    tags = to_show.map { |a| links_by_action[a].render }.compact.reduce(:<<)
    h.content_tag(:div, tags, class: "action-links")
  end
end
