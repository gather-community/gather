# frozen_string_literal: true

# Checks system status for use in the ping page.
class SystemStatus
  BACKUP_TIMES_FILE = "/var/log/latest-backup-times"
  SERVICES = %i[app database delayed_job redis elasticsearch backups].freeze

  def ok?
    statuses.values.all?
  end

  def statuses
    @statuses ||= SERVICES.map { |s| [s, send("#{s}_up?")] }.to_h
  end

  def app_up?
    true
  end

  def database_up?
    return @database_up if defined?(@database_up)
    @database_up = begin
      Cluster.count && true
    rescue ActiveRecord::StatementInvalid
      false
    end
  end

  def delayed_job_up?
    return @delayed_job_up if defined?(@delayed_job_up)
    @delayed_job_up =
      begin
        pid = delayed_job_pid
        pid.present? && Process.kill(0, pid) && true
      rescue Errno::ESRCH
        false
      end
  end

  def elasticsearch_up?
    return @elasticsearch_up if defined?(@elasticsearch_up)
    @elasticsearch_up =
      begin
        Work::Shift.search("foo").results.size && true
      rescue Faraday::ConnectionFailed
        false
      end
  end

  def redis_up?
    return @redis_up if defined?(@redis_up)
    @redis_up =
      begin
        Rails.cache.stats && true
      rescue Redis::CannotConnectError
        false
      end
  end

  def backups_up?
    return @backups_up if defined?(@backups_up)
    return (@backups_up = false) unless File.exist?(BACKUP_TIMES_FILE)
    @backups_up = File.read(BACKUP_TIMES_FILE).strip.split("\n").all? do |stamp|
      # The timestamp fetch operation runs an hour after the backup operation so we
      # do 26 hours instead of 24 to allow a little leeway.
      Time.current - Time.zone.parse(stamp) <= 26.hours
    end
  end

  private

  def delayed_job_pid
    File.read(Rails.root.join("tmp", "pids", "delayed_job.pid")).to_i
  rescue Errno::ENOENT
    nil
  end
end
