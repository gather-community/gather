# frozen_string_literal: true

module Calendars
  class SharedGuidelines < ApplicationRecord
    acts_as_tenant :cluster
    belongs_to :community
    has_many :guideline_inclusions, class_name: "Calendars::GuidelineInclusion",
                                    inverse_of: :shared_guidelines, dependent: :destroy
  end
end
