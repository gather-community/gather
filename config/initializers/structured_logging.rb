# frozen_string_literal: true

require_relative("../../lib/gather/structured_logger")

Rails.logger = Gather::StructuredLogger.new(Rails.logger)
