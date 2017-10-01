module Reservations
  class SharedGuidelines < ActiveRecord::Base
    acts_as_tenant :cluster
    belongs_to :community
    has_many :guideline_inclusions, class_name: "Reservations::GuidelineInclusion",
      inverse_of: :shared_guidelines, dependent: :destroy
  end
end
