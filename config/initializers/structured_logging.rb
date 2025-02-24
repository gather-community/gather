# frozen_string_literal: true

require_relative("../../lib/gather/structured_logger")

# The production logger already supports structured logging.
Rails.logger = Gather::StructuredLogger.new(Rails.logger) unless Rails.env.production?
