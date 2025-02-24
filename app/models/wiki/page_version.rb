# frozen_string_literal: true

# == Schema Information
#
# Table name: wiki_page_versions
#
#  id         :integer          not null, primary key
#  comment    :string
#  content    :text
#  number     :integer          not null
#  title      :string           not null
#  updated_at :datetime         not null
#  cluster_id :integer          not null
#  page_id    :integer          not null
#  updater_id :integer
#
# Indexes
#
#  index_wiki_page_versions_on_cluster_id          (cluster_id)
#  index_wiki_page_versions_on_page_id             (page_id)
#  index_wiki_page_versions_on_page_id_and_number  (page_id,number) UNIQUE
#  index_wiki_page_versions_on_updater_id          (updater_id)
#
# Foreign Keys
#
#  fk_rails_...  (cluster_id => clusters.id)
#  fk_rails_...  (page_id => wiki_pages.id)
#  fk_rails_...  (updater_id => users.id)
#
module Wiki
  class PageVersion < ApplicationRecord
    acts_as_tenant :cluster

    belongs_to :page, class_name: "Wiki::Page"
    belongs_to :updater, class_name: "User"

    before_update :raise_on_update

    def self.between(first, last)
      first = first.to_i
      last = last.to_i
      first, last = last, first if last < first
      where("number >= ? AND number <= ?", first, last)
    end

    def next
      self.class.first(conditions: ["id > ? AND page_id = ?", id, page_id], order: "id ASC")
    end

    def previous
      self.class.first(conditions: ["id < ? AND page_id = ?", id, page_id], order: "id DESC")
    end

    private

    def raise_on_update
      raise ActiveRecordError, "Can't modify existing version"
    end
  end
end
