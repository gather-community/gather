# == Schema Information
#
# Table name: meal_restrictions
#
#  id           :bigint           not null, primary key
#  absence      :string           not null
#  cluster_id   :bigint           not null
#  community_id :bigint           not null
#  contains     :string           not null
#  created_at   :datetime         not null
#  deactivated  :boolean          default(FALSE), not null
#  updated_at   :datetime         not null
#
FactoryBot.define do
  factory :restriction, class: 'Meals::Restriction' do
    contains { "Gluten" }
    absence { "Gluten-free" }
    community { Defaults.community }

  end
end
