# frozen_string_literal: true

class PopulateExistingCalendarColors < ActiveRecord::Migration[6.0]
  def up
    ActsAsTenant.without_tenant do
      Community.find_each do |community|
        ptr = 0
        populate_colors(Calendars::Node.in_community(community).arrange, ptr)
      end
    end
  end

  private

  def populate_colors(nodes, ptr)
    nodes.each do |node, children|
      if node.group?
        ptr = populate_colors(children, ptr)
      else
        node.update!(color: Calendars::Calendar::COLORS[ptr])
        ptr = (ptr + 1) % Calendars::Calendar::COLORS.size
      end
    end
    ptr
  end
end
