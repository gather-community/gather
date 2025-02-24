# frozen_string_literal: true

# == Schema Information
#
# Table name: people_memorials
#
#  id         :bigint           not null, primary key
#  birth_year :integer
#  death_year :integer          not null
#  obituary   :text
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  cluster_id :bigint           not null
#  user_id    :bigint           not null
#
# Indexes
#
#  index_people_memorials_on_cluster_id  (cluster_id)
#  index_people_memorials_on_user_id     (user_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (cluster_id => clusters.id)
#  fk_rails_...  (user_id => users.id)
#
module People
  class Memorial < ApplicationRecord
    acts_as_tenant :cluster

    belongs_to :user, inverse_of: :memorial
    has_many :messages, class_name: "People::MemorialMessage", inverse_of: :memorial, dependent: :destroy

    scope :in_community, ->(c) { joins(:user).merge(User.in_community(c)) }
    scope :by_user_name, -> { joins(:user).merge(User.by_name) }

    delegate :community, to: :user

    normalize_attributes :obituary

    validates :birth_year, :death_year, :user_id, presence: true
    validates :user_id, uniqueness: true
  end
end
