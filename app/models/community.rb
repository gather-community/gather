class Community < ActiveRecord::Base
  resourcify

  scope :by_name, -> { order("name") }

  serialize :settings
end
