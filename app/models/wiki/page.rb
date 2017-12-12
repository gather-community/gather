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

    after_save :create_new_version

    def self.find_by_path_or_new(path)
      find_by(path: path) || new(path: path, title: CGI.unescape(path))
    end

    def last_version_number
      versions.maximum(:number) || 0
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
  end
end
