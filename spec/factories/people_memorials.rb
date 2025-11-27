# == Schema Information
#
# Table name: people_memorials
#
#  id         :bigint           not null, primary key
#  birth_year :integer
#  cluster_id :bigint           not null
#  created_at :datetime         not null
#  death_year :integer          not null
#  obituary   :text
#  updated_at :datetime         not null
#  user_id    :bigint           not null
#
FactoryBot.define do
  factory :people_memorial, class: 'People::Memorial' do
    user { nil }
    birth_year { 1 }
    death_year { 1 }
  end
end
