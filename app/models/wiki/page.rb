module Wiki
  class Page < ActiveRecord::Base
    acts_as_tenant :cluster

    attr_accessor :comment

    belongs_to :community
    belongs_to :creator, class_name: "User"
    belongs_to :updator, class_name: "User"
    has_many :versions, -> { order('number DESC') }, class_name: "Wiki::PageVersion", dependent: :destroy

    scope :in_community, ->(c) { where(community_id: c.id) }
    scope :by_title, -> { order("LOWER(title)") }

    validates :title, presence: true

    before_save :set_slug
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
      n = last_version_number
      v = versions.build
      v.attributes = attributes.slice(*(v.attribute_names - ['id']))
      v.comment = comment
      v.number = n + 1
      v.save!
    end

    def set_slug
      self.slug = home? ? reserved_slug(:home) : title_to_slug(title)
    end

    def reserved_slug(type)
      self.class.reserved_slug(type)
    end

    def title_to_slug(title)
      self.class.title_to_slug(title)
    end
  end
end
