# frozen_string_literal: true

# Checks system status for use in the ping page.
class SystemStatus
  BACKUP_TIMES_FILE = "/var/log/latest-backup-times"
  SERVICES = %i[app database delayed_job redis elasticsearch backups mail].freeze

  def ok?
    statuses.values.all?
  end

  def statuses
    @statuses ||= SERVICES.index_with { |s| send("#{s}_up?") }
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
        Rails.logger.debug("[system status] Database down")
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
        Rails.logger.debug("[system status] Delayed Job down (process not running)")
        false
      end
  end

  def elasticsearch_up?
    return @elasticsearch_up if defined?(@elasticsearch_up)

    @elasticsearch_up =
      begin
        Work::Shift.search("foo").results.size && true
      rescue Faraday::ConnectionFailed
        Rails.logger.debug("[system status] Elasticsearch down (connection failed error)")
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
          Rails.logger.debug("[system status] Redis down (connected? returned false)")
          false
        end
      rescue Redis::CannotConnectError
        Rails.logger.debug("[system status] Redis down (cannot connect error)")
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
      Rails.logger.debug("[system status] Backups down (latest timestamp: #{latest}, zone: #{Time.zone})")
      false
    end
  end

  def mail_up?
    latest_received_mail_sent_at = MailTestRun.first&.mail_sent_at
    if latest_received_mail_sent_at
      ago = Time.current - latest_received_mail_sent_at
      Rails.logger.info("MAIL-UPTIME-LINE Last mail received at #{latest_received_mail_sent_at.to_fs}, #{ago} s ago")

      # If mail is sent at t, the next job picks it up at t + 5 mins and sends a new mail
      # So if things are working normally, the max age should be 10 mins give or take
      # So if it is more than 20 mins, we raise the alarm
      ago < 20 * 60
    else
      Rails.logger.info("MAIL-UPTIME-LINE No mail recieved")
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
