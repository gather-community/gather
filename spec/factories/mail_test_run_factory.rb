# frozen_string_literal: true

# == Schema Information
#
# Table name: mail_test_runs
#
#  id           :bigint           not null, primary key
#  counter      :integer          default(0)
#  created_at   :datetime         not null
#  mail_sent_at :datetime
#  updated_at   :datetime         not null
#
FactoryBot.define do
  factory :mail_test_run do
    mail_sent_at { "2024-10-16 21:35:26" }
    counter { 10 }
  end
end
