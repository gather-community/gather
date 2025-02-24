# frozen_string_literal: true

class ActionLinkSet < ApplicationDecorator
  attr_accessor :links_by_action, :actions

  def initialize(*links)
    self.links_by_action = links.index_by(&:action)
    self.actions = links_by_action.keys
  end

  def render(**options)
    options[:except] = Array.wrap(options[:except] || [])
    to_show = actions - options[:except]
    tags = to_show.map { |a| links_by_action[a].render }.compact

    # Group buttons nicely to avoid orphans. Assumes we won't have more than 6 buttons.
    slice_size = tags.size <= 4 ? 4 : 3
    tag_groups = tags.each_slice(slice_size).to_a
    tag_html = tag_groups.map { |g| h.tag.div(g.reduce(:<<), class: "action-link-group") }
    tag_html.reduce(:<<)
  end
end
