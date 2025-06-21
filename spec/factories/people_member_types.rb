# == Schema Information
#
# Table name: people_member_types
#
#  id           :bigint           not null, primary key
#  cluster_id   :bigint           not null
#  community_id :bigint           not null
#  created_at   :datetime         not null
#  name         :string(64)       not null
#  updated_at   :datetime         not null
#
FactoryBot.define do
  factory :people_member_type, class: 'People::MemberType' do
    name { "MyString" }
  end
end
