# frozen_string_literal: true

# == Schema Information
#
# Table name: calendar_nodes
#
#  id                    :integer          not null, primary key
#  abbrv                 :string(6)
#  allow_overlap         :boolean          default(TRUE), not null
#  cluster_id            :integer          not null
#  color                 :string(7)
#  community_id          :integer          not null
#  created_at            :datetime         not null
#  deactivated_at        :datetime
#  default_calendar_view :string           default("week"), not null
#  group_id              :bigint
#  guidelines            :text
#  meal_hostable         :boolean          default(FALSE), not null
#  name                  :string(24)       not null
#  rank                  :integer
#  selected_by_default   :boolean          default(FALSE), not null
#  type                  :string           not null
#  updated_at            :datetime         not null
#
module Calendars
  # Parent class of Calendars and Groups (composite design pattern).
  class Node < ApplicationRecord
    include Deactivatable
    include Rankable

    acts_as_tenant :cluster

    belongs_to :community

    validates :name, presence: true, uniqueness: {scope: :community_id}

    scope :in_community, ->(c) { where(community: c) }
    scope :by_cmty_and_name, -> { joins(:community).order("communities.abbrv, name") }
    scope :by_name, -> { alpha_order(:name) }
    scope :by_rank, -> { order(:rank) }
    scope :first_level, -> { where(group_id: nil) }
    scope :second_level, -> { where.not(group_id: nil) }
    scope :with_event_counts, lambda {
      select("calendar_nodes.*, (SELECT COUNT(id) FROM calendar_events
        WHERE calendar_id = calendar_nodes.id) AS event_count")
    }

    # Loads the scoped nodes and arranges them as a tree in an ordered hash.
    def self.arrange(decorator: nil)
      base_scope = deactivated_last.by_rank
      second_level = base_scope.second_level
      second_level = decorator.decorate_collection(second_level) if decorator.present?
      children_by_group_id = second_level.group_by(&:group_id)
      first_level = base_scope.first_level
      first_level = decorator.decorate_collection(first_level) if decorator.present?
      first_level.map { |n| [n, children_by_group_id[n.id] || {}] }.to_h
    end
  end
end
