module Wiki
  class PageVersion < ActiveRecord::Base
    acts_as_tenant :cluster

    belongs_to :page, class_name: "Wiki::Page"
    belongs_to :updator, class_name: "User"

    before_update :raise_on_update

    def self.between(first, last)
      first = first.to_i
      last = last.to_i
      first, last = last, first if last < first
      where('number >= ? AND number <= ?', first, last)
    end

    def next
      self.class.first conditions: ["id > ? AND page_id = ?", id, page_id], order: 'id ASC'
    end

    def previous
      self.class.first conditions: ["id < ? AND page_id = ?", id, page_id], order: 'id DESC'
    end

    private

    def raise_on_update
      raise ActiveRecordError, "Can't modify existing version"
    end
  end
end
