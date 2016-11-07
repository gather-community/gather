FactoryGirl.define do
  factory :statement, class: "Billing::Statement" do
    prev_balance "9.99"
    total_due "9.99"
    account
  end
end
