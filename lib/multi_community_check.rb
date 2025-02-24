# frozen_string_literal: true

module MultiCommunityCheck
  def multi_community?
    return @multi_community if defined?(@multi_community)

    @multi_community = Community.multiple?
  end
end
