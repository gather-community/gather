# frozen_string_literal: true

module GDrive
  module Migration
    class ScanTask < ApplicationRecord
      acts_as_tenant :cluster

      belongs_to :scan, inverse_of: :scan_tasks
    end
  end
end
