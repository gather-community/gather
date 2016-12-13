module People
  class Guardianship < ActiveRecord::Base
    belongs_to :guardian, class_name: "User"
    belongs_to :child, class_name: "User"
  end

  class AdultWithGuardianError < StandardError; end
end
