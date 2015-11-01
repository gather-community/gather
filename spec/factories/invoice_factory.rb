FactoryGirl.define do
  factory :invoice do
    prev_balance "9.99"
    total_due "9.99"
    due_on "2015-10-18"
    account
  end
end
