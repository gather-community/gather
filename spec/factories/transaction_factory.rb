FactoryGirl.define do
  factory :transaction do
    incurred_on "2015-10-18"
    code "meal"
    description "Some stuff"
    amount "9.99"
    account
  end
end
