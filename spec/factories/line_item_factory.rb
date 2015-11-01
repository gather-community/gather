FactoryGirl.define do
  factory :line_item do
    incurred_on "2015-10-18"
    code "meal"
    description "Some stuff"
    amount "9.99"
    household
  end
end
