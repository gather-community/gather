# frozen_string_literal: true

# == Schema Information
#
# Table name: gdrive_items
#
#  id               :bigint           not null, primary key
#  cluster_id       :bigint           not null
#  created_at       :datetime         not null
#  error_type       :string
#  external_id      :string(255)      not null
#  gdrive_config_id :bigint           not null
#  kind             :string           not null
#  name             :string           not null
#  updated_at       :datetime         not null
#
FactoryBot.define do
  factory :gdrive_item, class: "GDrive::Item" do
    transient do
      group { nil }
    end

    association :gdrive_config, factory: :gdrive_config
    kind { "drive" }
    sequence(:external_id) { |i| "xxx#{i}" }
    sequence(:name) { |i| "#{kind.capitalize} #{i}" }

    after :build do |item, evaluator|
      if evaluator.group
        item.item_groups.build(attributes_for(:gdrive_item_group, group_id: evaluator.group.id))
      end
    end
  end
end
