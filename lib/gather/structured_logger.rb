# frozen_string_literal: true

require "delegate"

module Gather
  # Wraps another logger to allow passing structured data as a second argument.
  # Uses SimpleDelegator so Rails-internal methods like broadcast_to are preserved.
  class StructuredLogger < SimpleDelegator
    def debug(message_or_progname = nil, data = nil, &block)
      message_or_progname = "#{message_or_progname} #{data.to_json}" unless data.nil?
      __getobj__.debug(message_or_progname, &block)
    end

    def info(message_or_progname = nil, data = nil, &block)
      message_or_progname = "#{message_or_progname} #{data.to_json}" unless data.nil?
      __getobj__.info(message_or_progname, &block)
    end

    def warn(message_or_progname = nil, data = nil, &block)
      message_or_progname = "#{message_or_progname} #{data.to_json}" unless data.nil?
      __getobj__.warn(message_or_progname, &block)
    end

    def error(message_or_progname = nil, data = nil, &block)
      message_or_progname = "#{message_or_progname} #{data.to_json}" unless data.nil?
      __getobj__.error(message_or_progname, &block)
    end
  end
end
