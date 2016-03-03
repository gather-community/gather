class HomepagePolicy < ApplicationPolicy
  def inactive?
    user.inactive?
  end
end