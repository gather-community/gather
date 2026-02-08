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
require "rails_helper"

describe GDrive::ItemGroup do
  it "has a valid factory" do
    create(:gdrive_item_group)
  end
end
