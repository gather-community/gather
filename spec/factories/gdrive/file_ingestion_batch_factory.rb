# frozen_string_literal: true

FactoryBot.define do
  factory :gdrive_file_ingestion_batch, class: "GDrive::FileIngestionBatch" do
    gdrive_config
    picked { {"docs" => [{"id" => "alfskjdkfa"}]} }
    status { "pending" }
  end
end
