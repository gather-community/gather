# frozen_string_literal: true

module GDrive
  module Migration
    class Log < ApplicationRecord
      acts_as_tenant :cluster

      belongs_to :operation, inverse_of: :logs
    end
  end
end
