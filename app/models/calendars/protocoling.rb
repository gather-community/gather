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
module Calendars
  # Join class for Calendar and Calendars::Protocol
  class Protocoling < ApplicationRecord
    acts_as_tenant :cluster

    belongs_to :protocol, class_name: "Calendars::Protocol"
    belongs_to :calendar, class_name: "Calendars::Calendar"
  end
end
