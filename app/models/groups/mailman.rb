# frozen_string_literal: true

module Groups
  # Sets table name prefix.
  module Mailman
    def self.table_name_prefix
      "group_mailman_"
    end
  end
end
