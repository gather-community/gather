# frozen_string_literal: true

FactoryBot.define do
  factory :mail_test_run do
    mail_sent_at { "2024-10-16 21:35:26" }
    counter { 10 }
  end
end
