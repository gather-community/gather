# frozen_string_literal: true

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
  end
end
