# frozen_string_literal: true

module Calendars
# == Schema Information
#
# Table name: calendar_protocolings
#
#  id          :integer          not null, primary key
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  calendar_id :integer          not null
#  cluster_id  :integer          not null
#  protocol_id :integer          not null
#
# Indexes
#
#  index_calendar_protocolings_on_cluster_id  (cluster_id)
#  protocolings_unique                        (calendar_id,protocol_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (calendar_id => calendar_nodes.id)
#  fk_rails_...  (cluster_id => clusters.id)
#  fk_rails_...  (protocol_id => calendar_protocols.id)
#
  # Join class for Calendar and Calendars::Protocol
  class Protocoling < ApplicationRecord
    acts_as_tenant :cluster

    belongs_to :protocol, class_name: "Calendars::Protocol"
    belongs_to :calendar, class_name: "Calendars::Calendar"
  end
end
