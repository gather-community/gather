# frozen_string_literal: true

# == Schema Information
#
# Table name: wiki_pages
#
#  id           :integer          not null, primary key
#  cluster_id   :integer          not null
#  community_id :integer          not null
#  content      :text
#  created_at   :datetime         not null
#  creator_id   :integer
#  data_source  :text
#  editable_by  :string           default("everyone"), not null
#  role         :string
#  slug         :string           not null
#  title        :string           not null
#  updated_at   :datetime         not null
#  updater_id   :integer
#
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
