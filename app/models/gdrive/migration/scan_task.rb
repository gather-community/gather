# frozen_string_literal: true

module GDrive
  module Migration
    class ScanTask < ApplicationRecord
      belongs_to :operation, inverse_of: :scan_tasks
    end
  end
end
