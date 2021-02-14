# frozen_string_literal: true

FactoryBot.define do
  factory :wiki_page, class: "Wiki::Page" do
    community { Defaults.community }
    content { Faker::Lorem.paragraph(sentence_count: 2) }
    association :creator, factory: :user
    updater { creator }
    title { Faker::Lorem.sentence(word_count: 3, supplemental: true, random_words_to_add: 1).gsub(".", "") }

    trait :with_data_source do
      data_source { "http://example.com" }
    end
  end
end
