# == Schema Information
#
# Table name: meal_restrictions
#
#  id             :bigint           not null, primary key
#  contains       :string(64)       not null
#  absence        :string(64)       not null
#  cluster_id     :bigint           not null
#  deactivated_at :datetime
#  deactivated    :boolean          not null
#  community_id   :bigint           not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#
FactoryBot.define do
  factory :restriction, class: 'Meals::Restriction' do
    contains { "Gluten" }
    absence { "Gluten-free" }
    community { Defaults.community }

  end
end
