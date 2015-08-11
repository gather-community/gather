class Location < ActiveRecord::Base
  scope :by_name, -> { order(:name) }
end
