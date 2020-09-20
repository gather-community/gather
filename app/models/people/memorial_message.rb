# frozen_string_literal: true

module People
  class MemorialMessage < ApplicationRecord
    acts_as_tenant :cluster

    belongs_to :memorial, inverse_of: :messages
    belongs_to :author, class_name: "User", inverse_of: :memorial_messages

    delegate :community, to: :memorial
  end
end
