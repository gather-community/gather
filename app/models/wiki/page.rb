# frozen_string_literal: true

# == Schema Information
#
# Table name: wiki_pages
#
#  id           :integer          not null, primary key
#  content      :text
#  data_source  :text
#  editable_by  :string           default("everyone"), not null
#  role         :string
#  slug         :string           not null
#  title        :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  cluster_id   :integer          not null
#  community_id :integer          not null
#  creator_id   :integer
#  updater_id   :integer
#
# Indexes
#
#  index_wiki_pages_on_cluster_id              (cluster_id)
#  index_wiki_pages_on_community_id            (community_id)
#  index_wiki_pages_on_community_id_and_slug   (community_id,slug) UNIQUE
#  index_wiki_pages_on_community_id_and_title  (community_id,title) UNIQUE
#  index_wiki_pages_on_creator_id              (creator_id)
#  index_wiki_pages_on_updater_id              (updater_id)
#
# Foreign Keys
#
#  fk_rails_...  (cluster_id => clusters.id)
#  fk_rails_...  (community_id => communities.id)
#  fk_rails_...  (creator_id => users.id)
#  fk_rails_...  (updater_id => users.id)
#
require "open-uri"

module Wiki
  # Models a single wiki page.
  class Page < ApplicationRecord
    acts_as_tenant :cluster

    RESERVED_SLUGS = Set.new(%w[new all home sample notfound]).freeze
    EDITABLE_BY_OPTIONS = %i[everyone wikiist].freeze

    attr_accessor :comment

    belongs_to :community
    belongs_to :creator, class_name: "User"
    belongs_to :updater, class_name: "User"
    has_many :versions, -> { order("number DESC") }, class_name: "Wiki::PageVersion", dependent: :destroy

    scope :in_community, ->(c) { where(community_id: c.id) }
    scope :by_title, -> { alpha_order(:title) }
    scope :related_to, ->(user) { where(creator: user).or(where(updater: user)) }

    validates :title, presence: true, uniqueness: {scope: :community}
    validate :slug_not_reserved
    validate :template_error
    validate :sample_not_editable

    before_validation :set_slug
    after_save :create_new_version

    def self.title_to_slug(title)
      # Uses babosa gem
      title.to_slug.normalize.to_s
    end

    def self.reserved_slug(role)
      role.to_s
    end

    def self.create_special_page(role, community:)
      create!(
        community: community,
        content: I18n.t("wiki.special_pages.#{role}.content"),
        role: role,
        title: I18n.t("wiki.special_pages.#{role}.title"),
        slug: reserved_slug(role)
      )
    end

    def special?
      role.present?
    end

    def home?
      role == "home"
    end

    def sample?
      role == "sample"
    end

    def last_version_number
      versions.maximum(:number) || 0
    end

    def to_param
      slug
    end

    private

    def create_new_version
      return unless saved_change_to_title? || saved_change_to_content? || comment.present?
      n = last_version_number
      v = versions.build
      v.attributes = attributes.slice(*(v.attribute_names - ["id"]))
      v.comment = comment
      v.number = n + 1
      v.save!
    end

    def set_slug
      self.slug = special? ? reserved_slug(role) : title_to_slug_without_dupes
    end

    def reserved_slug(type)
      self.class.reserved_slug(type)
    end

    # Gets the page's slug and avoids using one that is already taken.
    def title_to_slug_without_dupes
      base = title_to_slug(title)
      suffix = nil
      while other_page_exists_with_slug?(candidate = "#{base}#{suffix}")
        suffix = (suffix || 1) + 1
      end
      candidate
    end

    def other_page_exists_with_slug?(other_slug)
      self.class.in_community(community).where(slug: other_slug).where.not(id: id).exists?
    end

    def title_to_slug(title)
      self.class.title_to_slug(title)
    end

    def slug_not_reserved
      # We use title_to_slug and not title_to_slug_without_dupes here so that a page title of
      # 'Home' will raise a validation error.
      naive_slug = title_to_slug(title)
      errors.add(:title, :reserved_slug) if RESERVED_SLUGS.include?(naive_slug) && role != naive_slug
    end

    def template_error
      if data_source.present? && error = decorate.template_error
        errors.add(:content, error)
      end
    end

    def sample_not_editable
      errors.add(:base, :sample_not_editable) if sample? && persisted?
    end
  end
end
