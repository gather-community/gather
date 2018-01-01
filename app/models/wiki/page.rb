require 'open-uri'

module Wiki
  class Page < ApplicationRecord
    acts_as_tenant :cluster

    RESERVED_SLUGS = Set.new(%w(new all home notfound)).freeze
    EDITABLE_BY_OPTIONS = %i(everyone wikiist)

    attr_accessor :comment

    belongs_to :community
    belongs_to :creator, class_name: "User"
    belongs_to :updator, class_name: "User"
    has_many :versions, -> { order('number DESC') }, class_name: "Wiki::PageVersion", dependent: :destroy

    scope :in_community, ->(c) { where(community_id: c.id) }
    scope :by_title, -> { order("LOWER(title)") }

    validates :title, presence: true, uniqueness: {scope: :community}
    validate :slug_not_reserved

    before_validation :set_slug
    after_save :create_new_version

    def self.title_to_slug(title)
      # Uses babosa gem
      title.to_slug.normalize.to_s
    end

    def self.reserved_slug(type)
      type.to_s
    end

    def self.create_home_page(community:, creator:)
      create(
        community: community,
        creator: creator,
        updator: creator,
        content: I18n.t("wiki.home_page.content"),
        home: true,
        title: I18n.t("wiki.home_page.title"),
        slug: reserved_slug(:home)
      )
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
      v.attributes = attributes.slice(*(v.attribute_names - ['id']))
      v.comment = comment
      v.number = n + 1
      v.save!
    end

    def set_slug
      self.slug = home? ? reserved_slug(:home) : title_to_slug_without_dupes
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
      if RESERVED_SLUGS.include?(naive_slug)
        errors.add(:title, :reserved_slug)
      end
    end
  end
end
