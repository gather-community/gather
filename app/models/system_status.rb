# frozen_string_literal: true

# Checks system status for use in the ping page.
class SystemStatus
  def ok?
    delayed_job_up? && redis_up?
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

  private

  def delayed_job_pid
    File.read(Rails.root.join("tmp", "pids", "delayed_job.pid")).to_i
  rescue Errno::ENOENT
    nil
  end
end
