class Community < ActiveRecord::Base

  scope :by_name, -> { order("name") }

end
