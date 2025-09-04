# frozen_string_literal: true

# == Schema Information
#
# Table name: calendar_guideline_inclusions
#
#  id                   :integer          not null, primary key
#  calendar_id          :integer          not null
#  cluster_id           :integer          not null
#  shared_guidelines_id :integer          not null
#
# Join class for Calendar and SharedGuidelines
module Calendars
  class GuidelineInclusion < ApplicationRecord
    acts_as_tenant :cluster

    belongs_to :shared_guidelines, class_name: "Calendars::SharedGuidelines"
    belongs_to :calendar, class_name: "Calendars::Calendar"
  end
end
