# frozen_string_literal: true

require "rails_helper"

describe GDrive::FileIngestionBatch do
  it "has a valid factory" do
    create(:gdrive_file_ingestion_batch)
  end
end
