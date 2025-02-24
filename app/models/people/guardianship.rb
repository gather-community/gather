# frozen_string_literal: true

module People
# == Schema Information
#
# Table name: people_guardianships
#
#  id          :integer          not null, primary key
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  child_id    :integer          not null
#  cluster_id  :integer          not null
#  guardian_id :integer          not null
#
# Indexes
#
#  index_people_guardianships_on_child_id     (child_id)
#  index_people_guardianships_on_cluster_id   (cluster_id)
#  index_people_guardianships_on_guardian_id  (guardian_id)
#
# Foreign Keys
#
#  fk_rails_...  (child_id => users.id)
#  fk_rails_...  (cluster_id => clusters.id)
#  fk_rails_...  (guardian_id => users.id)
#
  # Join model between children and parents/guardians.
  class Guardianship < ApplicationRecord
    acts_as_tenant :cluster

    belongs_to :guardian, class_name: "User"
    belongs_to :child, class_name: "User"

    scope :related_to, ->(user) { where(guardian: user).or(where(child: user)) }
  end
end
