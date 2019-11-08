# frozen_string_literal: true

# For downloading files in system specs
module DownloadHelpers
  TIMEOUT = 10
  PATH    = Rails.root.join("tmp/downloads")

  module_function

  def downloads
    Dir[PATH.join("*")]
  end

  def download
    downloads.first
  end

  def download_content
    File.read(download)
  end

  def download_filename
    File.basename(download)
  end

  def wait_for_download
    Timeout.timeout(TIMEOUT) do
      sleep(0.1) until downloaded?
    end
  end

  def downloaded?
    !downloading? && downloads.any?
  end

  def downloading?
    downloads.grep(/\.crdownload$/).any?
  end

  def clear_downloads
    FileUtils.rm_f(downloads)
  end
end
