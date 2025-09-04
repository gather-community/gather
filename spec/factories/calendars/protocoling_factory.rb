# frozen_string_literal: true

# == Schema Information
#
# Table name: calendar_protocolings
#
#  id          :integer          not null, primary key
#  calendar_id :integer          not null
#  cluster_id  :integer          not null
#  created_at  :datetime         not null
#  protocol_id :integer          not null
#  updated_at  :datetime         not null
#
FactoryBot.define do
  factory :calendar_protocoling, class: "Calendars::Protocoling" do
    calendar
    protocol
  end
end
