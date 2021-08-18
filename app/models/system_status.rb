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
    @database_up =
      begin
        Cluster.count && true
      rescue ActiveRecord::StatementInvalid
        Rails.logger.debug("Database down")
        false
      end
  end

  def delayed_job_up?
    return true if Rails.env.test? # DJ doesn't run in test env.
    return @delayed_job_up if defined?(@delayed_job_up)
    @delayed_job_up =
      begin
        pid = delayed_job_pid
        pid.present? && Process.kill(0, pid) && true
      rescue Errno::ESRCH
        Rails.logger.debug("Delayed Job down (process not running)")
        false
      end
  end

  def elasticsearch_up?
    return @elasticsearch_up if defined?(@elasticsearch_up)
    @elasticsearch_up =
      begin
        Work::Shift.search("foo").results.size && true
      rescue Faraday::ConnectionFailed
        Rails.logger.debug("Elasticsearch down (connection failed error)")
        false
      end
  end

  def redis_up?
    return true if Rails.env.test? # Redis doesn't run in test env.
    return @redis_up if defined?(@redis_up)
    @redis_up =
      begin
        Rails.cache.redis.get("__foo__") # Force connection to be established
        if Rails.cache.redis.connected?
          true
        else
          Rails.logger.debug("Redis down (connected? returned false)")
          false
        end
      rescue Redis::CannotConnectError
        Rails.logger.debug("Redis down (cannot connect error)")
        false
      end
  end

  def backups_up?
    return true if Rails.env.test? # We don't want to make real s3cmd calls in tests.
    return @backups_up if defined?(@backups_up)

    latest = `s3cmd ls s3://gather-db-backups`.split("\n").map { |l| l.split("/")[-1][0...-5] }.max

    # The timestamp fetch operation runs an hour after the backup operation so we
    # do 26 hours instead of 24 to allow a little leeway.
    if (@backups_up = Time.current - Time.zone.parse("#{latest} UTC") <= 26.hours)
      true
    else
      Rails.logger.debug("Backups down (latest timestamp: #{latest})")
      false
    end
  end

  private

  def delayed_job_pid
    File.read(Rails.root.join("tmp", "pids", "delayed_job.pid")).to_i
  rescue Errno::ENOENT
    nil
  end
end
