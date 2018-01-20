FactoryBot.define do
  factory :work_period, class: "Work::Period" do
    starts_on "2018-01-20"
    ends_on "2018-02-20"
    community
    cluster
  end
end
