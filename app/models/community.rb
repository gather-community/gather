class Community < ActiveRecord::Base

  scope :by_name, -> { order("name") }

  serialize :settings

end
