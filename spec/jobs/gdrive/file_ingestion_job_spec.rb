# frozen_string_literal: true

require "rails_helper"

describe GDrive::FileIngestionJob do
  include_context "jobs"

  # let!(:gdrive_config) { create(:gdrive_migration_config) }

  # context "happy path" do
  #   let!(:batch) do
  #     create(:gdrive_file_ingestion_batch,
  #            gdrive_config: gdrive_config,
  #            picked: {
  #              "docs" => [
  #                {"id" => "1rewJdE-UySaFWHw0NpVfxmNGGOLsD6rbCUwkLjiLc5I"},
  #                {"id" => "0B3vqeGRChC_MV2VUbmdSbkpxVEU"}
  #               ]
  #            })
  #   end
  #   subject(:job) { described_class.new(cluster_id: Defaults.cluster.id, batch_id: batch.id) }

  #   it "sends requests to star files and creates unowned file records" do
  #     VCR.use_cassette("gdrive/file_ingestion_job/success") do
  #       perform_job
  #       expect(GDrive::UnownedFile.count).to eq(2)
  #       files = GDrive::UnownedFile.order(:external_id).to_a
  #       expect(files[0].external_id).to eq("0B3vqeGRChC_MV2VUbmdSbkpxVEU")
  #       expect(files[0].gdrive_config_id).to eq(gdrive_config.id)
  #       expect(files[0].owner).to eq("foo@gmail.com")
  #       expect(files[0].data["name"]).to eq("_DSF1341.jpg")
  #       expect(files[0].data["mime_type"]).to eq("image/jpeg")
  #       expect(files[0].data["shortcut_details"]).to be_nil
  #       expect(files[1].external_id).to eq("1rewJdE-UySaFWHw0NpVfxmNGGOLsD6rbCUwkLjiLc5I")
  #       expect(files[1].gdrive_config_id).to eq(gdrive_config.id)
  #       expect(files[1].owner).to eq("bar@gmail.com")
  #       expect(files[1].data["name"]).to eq("Touchstone Committee Payment Authorization")
  #       expect(files[1].data["mime_type"]).to eq("application/vnd.google-apps.form")
  #       expect(files[1].data["shortcut_details"]).to be_nil
  #     end
  #   end
  # end

  # context "when there is an http error on adding star" do
  #   let!(:batch) do
  #     create(:gdrive_file_ingestion_batch,
  #            gdrive_config: gdrive_config,
  #            picked: {
  #              "docs" => [
  #                {"id" => "123", "name" => "Foo File"},
  #                {"id" => "456", "name" => "Bar File"},
  #                {"id" => "789", "name" => "Baz File"}
  #              ]
  #            })
  #   end
  #   subject(:job) { described_class.new(cluster_id: Defaults.cluster.id, batch_id: batch.id) }

  #   before do
  #     stub_const("#{described_class.name}::MAX_ERRORS", 2)
  #   end

  #   it "continues processing, saves MAX_ERRORS errors" do
  #     VCR.use_cassette("gdrive/file_ingestion_job/http_errors") do
  #       perform_job
  #       expect(GDrive::UnownedFile.count).to eq(0)
  #       batch.reload
  #       expect(batch.http_errors).to eq([
  #         {"id" => "123", "name" => "Foo File", "message" => "Unauthorized"},
  #         {"id" => "456", "name" => "Bar File", "message" => "Unauthorized"}
  #       ])
  #     end
  #   end
  # end

  # context "when trying to ingest shortcut when we don't have access to target" do
  #   let!(:batch) do
  #     create(:gdrive_file_ingestion_batch,
  #            gdrive_config: gdrive_config,
  #            picked: {
  #              "docs" => [
  #                # This is the ID of the target file, as that's what the Google Picker gives us.
  #                {"id" => "1H2S6WdUs7iVgs14ZRt_0xZybclzHy41Bl7rDC1Yqpyc"},
  #               ]
  #            })
  #   end
  #   subject(:job) { described_class.new(cluster_id: Defaults.cluster.id, batch_id: batch.id) }

  #   it "does not error out, does not report error, saves shortcut as unowned" do
  #     VCR.use_cassette("gdrive/file_ingestion_job/shortcut_no_access") do
  #       perform_job
  #       expect(GDrive::UnownedFile.count).to eq(1)
  #       # This is the ID of the shortcut, not the target file
  #       expect(GDrive::UnownedFile.first.external_id).to eq("1G8kly1IDekfawcu_tEr8f6vX7ckuBkXj")
  #       batch.reload
  #       expect(batch.http_errors).to be_empty
  #     end
  #   end
  # end

  # context "with file already recorded as unowned" do
  #   let!(:unowned_file) do
  #     create(:gdrive_unowned_file, gdrive_config: gdrive_config,
  #                                  external_id: "1rewJdE-UySaFWHw0NpVfxmNGGOLsD6rbCUwkLjiLc5I")
  #   end
  #   let!(:batch) do
  #     create(:gdrive_file_ingestion_batch,
  #            gdrive_config: gdrive_config,
  #            picked: {
  #              "docs" => [
  #                {"id" => "1rewJdE-UySaFWHw0NpVfxmNGGOLsD6rbCUwkLjiLc5I"},
  #                {"id" => "0B3vqeGRChC_MV2VUbmdSbkpxVEU"}
  #               ]
  #            })
  #   end
  #   subject(:job) { described_class.new(cluster_id: Defaults.cluster.id, batch_id: batch.id) }

  #   it "does not error out, does not report error" do
  #     VCR.use_cassette("gdrive/file_ingestion_job/already_unowned") do
  #       perform_job
  #       expect(GDrive::UnownedFile.count).to eq(2)
  #       files = GDrive::UnownedFile.order(:external_id).to_a
  #       expect(files[0].external_id).to eq("0B3vqeGRChC_MV2VUbmdSbkpxVEU")
  #       expect(files[1].external_id).to eq("1rewJdE-UySaFWHw0NpVfxmNGGOLsD6rbCUwkLjiLc5I")
  #     end
  #   end
  # end
end
