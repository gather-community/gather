module Work
  class Job < ApplicationRecord
    TIMES_OPTIONS = %i(date_time date_only full_period)
    SLOT_TYPE_OPTIONS = %i(fixed full_single full_multiple)

    acts_as_tenant :cluster

    belongs_to :community
    belongs_to :period, class_name: "Work::Period"
    belongs_to :requester, class_name: "People::Group"

    scope :for_community, ->(c) { where(community_id: c.id) }

    validates :period, presence: true
    validates :title, presence: true, length: {maximum: 128}
    validates :hours, presence: true, numericality: {greater_than: 0}
    validates :times, presence: true
    validates :slot_type, presence: true
    validates :description, presence: true
  end
end
