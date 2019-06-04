FactoryBot.define do
  factory :wiki_page, class: "Wiki::Page" do
    community { Defaults.community }
    content { Faker::Lorem.paragraph(2) }
    association :creator, factory: :user
    updator { creator }
    title { Faker::Lorem.sentence(3, true, 1).gsub(".", "") }

    trait :with_data_source do
      data_source { "http://example.com" }
    end
  end
end
