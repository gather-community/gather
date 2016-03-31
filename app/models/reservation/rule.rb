# Models a single reservation rule, such as max_minutes_per_year = 200.
# Also stores a reference to the Reservation::Protocol giving rise to the rule.
module Reservation
  class Rule
    attr_accessor :name, :value, :protocol

    def initialize(name: nil, value: nil, protocol: nil)
      self.name = name
      self.value = value
      self.protocol = protocol
    end
  end
end
