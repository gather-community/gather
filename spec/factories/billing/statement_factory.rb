# frozen_string_literal: true

# == Schema Information
#
# Table name: statements
#
#  id            :integer          not null, primary key
#  account_id    :integer          not null
#  cluster_id    :integer          not null
#  created_at    :datetime         not null
#  due_on        :date
#  prev_balance  :decimal(10, 2)   not null
#  prev_stmt_on  :date
#  reminder_sent :boolean          default(FALSE), not null
#  total_due     :decimal(10, 2)   not null
#  updated_at    :datetime         not null
#
FactoryBot.define do
  factory :statement, class: "Billing::Statement" do
    prev_balance { "9.99" }
    total_due { "9.99" }
    account
  end
end
