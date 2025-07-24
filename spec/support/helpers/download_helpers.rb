# frozen_string_literal: true

# For downloading files in system specs
module DownloadHelpers
  TIMEOUT = 10
  PATH    = Rails.root.join("tmp/downloads")

  module_function

  def wait_for_downloads
    Timeout.timeout(TIMEOUT) do
      sleep(0.1)
      downloads = list_downloads
      return downloads if downloads.none? { |d| d.end_with?(".crdownload") } && downloads.any?
    end
  end

  def clear_downloads
    FileUtils.rm_f(list_downloads)
  end

  private

  def list_downloads
    Dir[PATH.join("*")]
  end
end
