class Assignment < ActiveRecord::Base
  ROLES = %w(head_cook asst_cook cleaner) # In order

  belongs_to :user
  belongs_to :meal

  def empty?
    user_id.blank?
  end

  def <=>(other)
    ROLES.index(role) <=> ROLES.index(other.role)
  end
end
