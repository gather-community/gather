# frozen_string_literal: true

# == Schema Information
#
# Table name: community_signups
#
#  id                  :bigint           not null, primary key
#  contact_first_name  :string           not null
#  contact_last_name   :string           not null
#  contact_email       :string           not null
#  community_name      :string(20)       not null
#  slug                :string(63)       not null
#  country_code        :string(2)        default("US"), not null
#  time_zone           :string           not null, default("UTC")
#  introduction        :text             not null
#  want_sample_data    :boolean          not null, default(false)
#  status              :string           not null, default("pending")
#  message             :text
#  reviewed_at         :datetime
#  reviewed_by_id      :bigint
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#

module Communities
  class Signup < ApplicationRecord
    CONTACT_NAME_MAX_LENGTH = 255
    CONTACT_EMAIL_MAX_LENGTH = 254
    TIME_ZONE_MAX_LENGTH = 64
    COMMUNITY_NAME_MAX_LENGTH = 20
    SLUG_MAX_LENGTH = 20
    INTRODUCTION_MAX_LENGTH = 5000
    MESSAGE_MAX_LENGTH = 5000
    WANT_SAMPLE_DATA_OPTIONS = %i[true false].freeze

    enum :status, {pending: "pending", approved: "approved", denied: "denied",
                   created: "created", failed: "failed"}

    belongs_to :reviewed_by, class_name: "User", optional: true

    # Country codes are ISO 3166-1 alpha-2 and must be stored uppercase to match Community.
    before_validation { self.country_code = country_code&.upcase }

    validates :slug, uniqueness: true

    def contact_name
      "#{contact_first_name} #{contact_last_name}"
    end

    def deny!(reviewer, message: nil)
      update!(status: :denied, reviewed_by: reviewer, reviewed_at: Time.current, message: message)
    end

    def approve!(reviewer, message:)
      update!(status: :approved, reviewed_by: reviewer, reviewed_at: Time.current, message: message)
    end

    def mark_created!
      update!(status: :created)
    end

    def mark_failed!(message:)
      update!(status: :failed, failure_message: message)
    end
  end
end
