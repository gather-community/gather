FactoryBot.define do
  factory :gdrive_item_group, class: "GDrive::ItemGroup" do
    association(:item, factory: :gdrive_item)
    group
    access_level { "reader" }
  end
end
