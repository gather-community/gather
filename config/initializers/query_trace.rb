# frozen_string_literal: true

if Rails.env.development? || ENV["QUERY_TRACE"]
  # yeilds a stacktrace for each SQL query
  # put this file in config/initializers
  class QueryTrace < ActiveSupport::LogSubscriber
    attr_accessor :trace_queries

    def sql(_event) # :nodoc:
      return unless QueryTrace.enabled? && logger.debug?

      stack = Rails.backtrace_cleaner.clean(caller)
      first_line = stack.shift
      return unless first_line

      msg = prefix + "#{first_line}\n"
      msg += stack.join("\n")
      debug(msg)
    end

    # :call-seq:
    # Klass.enabled?
    #
    # yields boolean if SQL queries should be signed or not

    def self.enabled?
      defined?(@trace_queries) && @trace_queries
    end

    # :call-seq:
    # Klass.status
    #
    # yields text if QueryTrace has been enabled or not

    def self.status
      QueryTrace.enabled? ? "enabled" : "disabled"
    end

    # :call-seq:
    # Klass.enable!
    #
    # turn on SQL query origin logging

    def self.enable!
      @trace_queries = true
    end

    # :call-seq:
    # Klass.disable!
    #
    # turn off SQL query origin logging

    def self.disable!
      @trace_queries = false
    end

    # :call-seq:
    # Klass.toggle!
    #
    # Toggles query tracing yielding a boolean indicating the new state of query
    # origin tracing

    def self.toggle!
      enabled? ? disable! : enable!
      enabled?
    end

    protected

    def prefix # :nodoc:
      "Called from: "
    end
  end

  QueryTrace.attach_to(:active_record)

  trap("QUIT") do
    # Sending 2 backspace characters removes the ^\ that is
    # printed to the console.
    rm_noise = "\b\b"

    QueryTrace.toggle!
    puts "#{rm_noise}=> QueryTrace #{QueryTrace.status}"
  end

  QueryTrace.enable! if ENV["QUERY_TRACE"]
  puts("=> QueryTrace #{QueryTrace.status}; CTRL-\\ to toggle")
end
