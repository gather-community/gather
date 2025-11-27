# frozen_string_literal: true

# == Schema Information
#
# Table name: people_memorial_messages
#
#  id          :bigint           not null, primary key
#  author_id   :bigint           not null
#  body        :text             not null
#  cluster_id  :bigint
#  created_at  :datetime         not null
#  memorial_id :bigint           not null
#  updated_at  :datetime         not null
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
