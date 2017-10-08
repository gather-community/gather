FactoryGirl.define do
  factory :wiki_page, class: "Wiki::Page" do
    community { default_community }
    content { Faker::Lorem.paragraph(2) }
    association :creator, factory: :user
    title { Faker::Lorem.sentence(3, true, 1).gsub(".", "") }
    path { CGI.escape(title) }
  end
end
