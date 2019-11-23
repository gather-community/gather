# frozen_string_literal: true

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
