# A lens is a set of parameters that scope an index listing, e.g. search, filter, pagination.
module Lensable
  extend ActiveSupport::Concern

  included do
    attr_reader :lens
    helper_method :lens
  end

  def prepare_lens(*fields)
    @lens = Lens.new(context: self, fields: fields, params: params)
  end

  def load_community_from_lens_with_default
    if lens[:community]
      @community = Community.find_by_abbrv(lens[:community])
    else
      @community = current_community
      lens[:community] = @community.lc_abbrv
    end
  end
end
