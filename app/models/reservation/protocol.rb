module Reservation
  class Protocol < ActiveRecord::Base
    belongs_to :resource

    serialize :kinds

    def self.find_best(resource, kind = nil)
      where(resource: resource).
        select { |p| p.has_kind?(kind) || p.kinds.nil? }.
        sort_by { |p| p.has_kind?(kind) ? 1 : 10 }.
        first
    end

    def has_kind?(k)
      kinds.present? && kinds.include?(k)
    end
  end
end
