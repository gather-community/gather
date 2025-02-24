# frozen_string_literal: true

# Join class for Calendar and SharedGuidelines
# == Schema Information
#
# Table name: calendar_guideline_inclusions
#
#  id                   :integer          not null, primary key
#  calendar_id          :integer          not null
#  cluster_id           :integer          not null
#  shared_guidelines_id :integer          not null
#
# Indexes
#
#  index_calendar_guideline_inclusions_on_cluster_id  (cluster_id)
#  index_reservation_guideline_inclusions             (calendar_id,shared_guidelines_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (calendar_id => calendar_nodes.id)
#  fk_rails_...  (cluster_id => clusters.id)
#  fk_rails_...  (shared_guidelines_id => calendar_shared_guidelines.id)
#
module Calendars
  class GuidelineInclusion < ApplicationRecord
    acts_as_tenant :cluster

    belongs_to :shared_guidelines, class_name: "Calendars::SharedGuidelines"
    belongs_to :calendar, class_name: "Calendars::Calendar"
  end
end
