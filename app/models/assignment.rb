class Assignment < ActiveRecord::Base
  belongs_to :user
  belongs_to :meal

  def empty?
    user_id.blank?
  end
end
