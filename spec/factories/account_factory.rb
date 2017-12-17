FactoryBot.define do
  factory :account, class: "Billing::Account" do
    household
    community { default_community }
    last_statement_on "2015-10-27"
    due_last_statement "8.81"
    total_new_credits "10.99"
    total_new_charges "22.71"
  end
end
