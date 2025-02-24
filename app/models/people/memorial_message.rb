# frozen_string_literal: true

# == Schema Information
#
# Table name: people_memorial_messages
#
#  id          :bigint           not null, primary key
#  body        :text             not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  author_id   :bigint           not null
#  cluster_id  :bigint
#  memorial_id :bigint           not null
#
# Indexes
#
#  index_people_memorial_messages_on_author_id    (author_id)
#  index_people_memorial_messages_on_cluster_id   (cluster_id)
#  index_people_memorial_messages_on_created_at   (created_at)
#  index_people_memorial_messages_on_memorial_id  (memorial_id)
#
# Foreign Keys
#
#  fk_rails_...  (author_id => users.id)
#  fk_rails_...  (memorial_id => people_memorials.id)
#
module People
  class MemorialMessage < ApplicationRecord
    acts_as_tenant :cluster

    belongs_to :memorial, inverse_of: :messages
    belongs_to :author, class_name: "User", inverse_of: :memorial_messages

    delegate :community, to: :memorial

    normalize_attributes :body

    validates :body, presence: true
  end
end
