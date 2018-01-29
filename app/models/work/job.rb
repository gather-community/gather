module Work
  class Job < ApplicationRecord
    TIMES_OPTIONS = %i(date_time date_only full_period)
    SLOT_TYPE_OPTIONS = %i(fixed full_single full_multiple)

    acts_as_tenant :cluster

    belongs_to :community
    belongs_to :period, class_name: "Work::Period"
    belongs_to :requester, class_name: "People::Group"
    has_many :shifts, class_name: "Work::Shift", inverse_of: :job

    scope :for_community, ->(c) { where(community_id: c.id) }

    validates :period, presence: true
    validates :title, presence: true, length: {maximum: 128}
    validates :hours, presence: true, numericality: {greater_than: 0}
    validates :time_type, presence: true
    validates :slot_type, presence: true
    validates :description, presence: true

    accepts_nested_attributes_for :shifts, reject_if: :all_blank, allow_destroy: true

    delegate :starts_on, :ends_on, to: :period, prefix: true

    def full_period?
      time_type == "full_period"
    end
  end
end
