# frozen_string_literal: true

# == Schema Information
#
# Table name: calendar_shared_guidelines
#
#  id           :integer          not null, primary key
#  body         :text             not null
#  name         :string(64)       not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  cluster_id   :integer          not null
#  community_id :integer          not null
#
# Indexes
#
#  index_calendar_shared_guidelines_on_cluster_id    (cluster_id)
#  index_calendar_shared_guidelines_on_community_id  (community_id)
#
# Foreign Keys
#
#  fk_rails_...  (cluster_id => clusters.id)
#  fk_rails_...  (community_id => communities.id)
#
module Calendars
  class SharedGuidelines < ApplicationRecord
    acts_as_tenant :cluster
    belongs_to :community
    has_many :guideline_inclusions, class_name: "Calendars::GuidelineInclusion",
                                    inverse_of: :shared_guidelines, dependent: :destroy
  end
end
