# == Schema Information
#
# Table name: gdrive_item_groups
#
#  id           :bigint           not null, primary key
#  access_level :string           not null
#  cluster_id   :bigint           not null
#  created_at   :datetime         not null
#  group_id     :bigint           not null
#  item_id      :bigint           not null
#  updated_at   :datetime         not null
#
FactoryBot.define do
  factory :gdrive_item_group, class: "GDrive::ItemGroup" do
    association(:item, factory: :gdrive_item)
    group
    access_level { "reader" }
  end
end
