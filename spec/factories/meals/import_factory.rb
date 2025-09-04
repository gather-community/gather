# frozen_string_literal: true

# == Schema Information
#
# Table name: meal_imports
#
#  id            :bigint           not null, primary key
#  cluster_id    :bigint           not null
#  community_id  :bigint           not null
#  created_at    :datetime         not null
#  errors_by_row :jsonb
#  status        :string           default("queued"), not null
#  updated_at    :datetime         not null
#  user_id       :bigint           not null
#
FactoryBot.define do
  factory :meal_import, class: "Meals::Import" do
    transient do
      csv { "" }
    end

    community { Defaults.community }
    user

    after(:build) do |import, evaluator|
      import.file.attach(io: StringIO.new(evaluator.csv), filename: "input.csv") unless evaluator.csv.nil?
    end
  end
end
