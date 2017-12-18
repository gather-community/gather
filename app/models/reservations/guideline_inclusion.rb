# Join class for Resource and SharedGuidelines
module Reservations
  class GuidelineInclusion < ApplicationRecord
    acts_as_tenant(:cluster)

    belongs_to :shared_guidelines, class_name: "Reservations::SharedGuidelines"
    belongs_to :resource
  end
end
