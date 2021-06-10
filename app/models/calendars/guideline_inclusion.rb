# frozen_string_literal: true

# Join class for Calendar and SharedGuidelines
module Calendars
  class GuidelineInclusion < ApplicationRecord
    acts_as_tenant :cluster

    belongs_to :shared_guidelines, class_name: "Calendars::SharedGuidelines"
    belongs_to :calendar, class_name: "Calendars::Calendar"
  end
end
