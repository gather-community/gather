# frozen_string_literal: true

# == Schema Information
#
# Table name: calendar_protocols
#
#  id                   :integer          not null, primary key
#  cluster_id           :integer          not null
#  community_id         :integer          not null
#  created_at           :datetime         not null
#  fixed_end_time       :time
#  fixed_start_time     :time
#  kinds                :jsonb
#  max_days_per_year    :integer
#  max_lead_days        :integer
#  max_length_minutes   :integer
#  max_minutes_per_year :integer
#  name                 :string           not null
#  other_communities    :string
#  pre_notice           :text
#  requires_kind        :boolean
#  updated_at           :datetime         not null
#
FactoryBot.define do
  factory :calendar_protocol, class: "Calendars::Protocol" do
    transient do
      calendars { [] }
    end

    sequence(:name) { |i| "Protocol #{i}" }
    kinds { nil }
    community { calendars.first&.community || Defaults.community }

    after(:create) do |protocol, evaluator|
      protocol.calendars = evaluator.calendars
    end
  end
end
