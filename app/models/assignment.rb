class Assignment < ActiveRecord::Base
  ROLE_ORDER = %w(head_cook asst_cook cleaner)

  belongs_to :user
  belongs_to :meal

  def empty?
    user_id.blank?
  end

  def <=>(other)
    ROLE_ORDER.index(role) <=> ROLE_ORDER.index(other.role)
  end
end
