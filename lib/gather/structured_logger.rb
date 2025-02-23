# frozen_string_literal: true

module Gather
  # Wraps another logger class to allow passing structured data.
  class StructuredLogger < ActiveSupport::Logger
    attr_accessor :base_logger

    def initialize(base_logger)
      self.base_logger = base_logger
      self.level = base_logger.level
    end

    def debug(message_or_progname = nil, data = nil, &)
      message_or_progname = "#{message_or_progname} #{data.to_json}" unless data.nil?
      base_logger.debug(message_or_progname, &)
    end

    def info(message_or_progname = nil, data = nil, &)
      message_or_progname = "#{message_or_progname} #{data.to_json}" unless data.nil?
      base_logger.info(message_or_progname, &)
    end

    def warn(message_or_progname = nil, data = nil, &)
      message_or_progname = "#{message_or_progname} #{data.to_json}" unless data.nil?
      base_logger.warn(message_or_progname, &)
    end

    def error(message_or_progname = nil, data = nil, &)
      message_or_progname = "#{message_or_progname} #{data.to_json}" unless data.nil?
      base_logger.error(message_or_progname, &)
    end
  end
end
