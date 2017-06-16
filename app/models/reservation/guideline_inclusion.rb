# Join class for Resource and SharedGuidelines
module Reservation
  class GuidelineInclusion < ActiveRecord::Base
    acts_as_tenant(:cluster)

    belongs_to :shared_guidelines, class_name: "Reservation::SharedGuidelines"
    belongs_to :resource
  end
end
