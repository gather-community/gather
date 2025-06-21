# frozen_string_literal: true

# == Schema Information
#
# Table name: roles
#
#  id            :integer          not null, primary key
#  created_at    :datetime
#  name          :string
#  resource_id   :integer
#  resource_type :string
#  updated_at    :datetime
#
class Role < ApplicationRecord
  has_and_belongs_to_many :users, join_table: :users_roles
  belongs_to :resource, polymorphic: true

  validates :resource_type,
            inclusion: {in: Rolify.resource_types},
            allow_nil: true

  scopify
end
