FactoryGirl.define do
  factory :account do
    household
    last_invoiced_on "2015-10-27"
    due_last_invoice "8.81"
    total_new_credits "10.99"
    total_new_charges "22.71"
  end
end
