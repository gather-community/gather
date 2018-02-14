# A lens is a set of parameters that scope an index listing, e.g. search, filter, pagination.
module Lensable
  extend ActiveSupport::Concern

  included do
    attr_reader :lens
    helper_method :lens
  end

  def prepare_lens(*fields)
    @lens = Lens::Lens.new(context: self, fields: fields, params: params)
  end

  def lens_communities
    if lens[:community] == "all" || lens[:community].blank?
      current_cluster.communities
    else
      current_community
    end
  end
end
