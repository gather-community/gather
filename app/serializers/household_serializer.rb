# frozen_string_literal: true

# == Schema Information
#
# Table name: households
#
#  id             :integer          not null, primary key
#  alternate_id   :string
#  cluster_id     :integer          not null
#  community_id   :integer          not null
#  created_at     :datetime         not null
#  deactivated_at :datetime
#  garage_nums    :string
#  keyholders     :string
#  member_type_id :bigint
#  name           :string(50)       not null
#  unit_num       :integer
#  unit_suffix    :string
#  updated_at     :datetime         not null
#
class HouseholdSerializer < ApplicationSerializer
  attributes :id, :name, :name_with_prefix
  delegate :name_with_prefix, to: :decorated
end
