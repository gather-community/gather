# frozen_string_literal: true

# == Schema Information
#
# Table name: calendar_shared_guidelines
#
#  id           :integer          not null, primary key
#  body         :text             not null
#  cluster_id   :integer          not null
#  community_id :integer          not null
#  created_at   :datetime         not null
#  name         :string(64)       not null
#  updated_at   :datetime         not null
#
module Calendars
  class SharedGuidelines < ApplicationRecord
    acts_as_tenant :cluster
    belongs_to :community
    has_many :guideline_inclusions, class_name: "Calendars::GuidelineInclusion",
                                    inverse_of: :shared_guidelines, dependent: :destroy
  end
end
