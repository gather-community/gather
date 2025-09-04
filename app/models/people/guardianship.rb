# frozen_string_literal: true

# == Schema Information
#
# Table name: people_guardianships
#
#  id          :integer          not null, primary key
#  child_id    :integer          not null
#  cluster_id  :integer          not null
#  created_at  :datetime         not null
#  guardian_id :integer          not null
#  updated_at  :datetime         not null
#
module People
  # Join model between children and parents/guardians.
  class Guardianship < ApplicationRecord
    acts_as_tenant :cluster

    belongs_to :guardian, class_name: "User"
    belongs_to :child, class_name: "User"

    scope :related_to, ->(user) { where(guardian: user).or(where(child: user)) }
  end
end
