# frozen_string_literal: true

# Checks system status for use in the ping page.
class SystemStatus
  BACKUP_TIMES_FILE = "/var/log/latest-backup-times"

  def ok?
    database_up? && delayed_job_up? && redis_up? && backups_recent?
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

  def redis_up?
    return @redis_up if defined?(@redis_up)
    @redis_up =
      begin
        Rails.cache.stats && true
      rescue Redis::CannotConnectError
        false
      end
  end

  def backups_recent?
    return @backups_recent if defined?(@backups_recent)
    return (@backups_recent = false) unless File.exist?(BACKUP_TIMES_FILE)
    @backups_recent = File.read(BACKUP_TIMES_FILE).strip.split("\n").all? do |stamp|
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
