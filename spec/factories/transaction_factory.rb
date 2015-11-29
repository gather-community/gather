FactoryGirl.define do
  factory :transaction do
    incurred_on "2015-10-18"
    code "othchg"
    description "Some stuff"
    amount "9.99"
    account

    factory :credit do
      code "payment"
      amount "-9.99"
    end

    factory :charge do
    end
  end
end
