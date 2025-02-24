# frozen_string_literal: true

require "rails_helper"

describe GDrive::Migration::WebhookRefreshJob do
  include_context "jobs"

  let(:community) { create(:community, id: 123) }
  let!(:main_config) do
    create(:gdrive_main_config, community: community, org_user_id: "workspace.admin@touchstonecohousing.org")
  end
  let!(:token) do
    create(:gdrive_token, gdrive_config: main_config, google_user_id: main_config.org_user_id,
                          access_token: "ya29.a0AfB_byDbkQ6Z6aG9nLFlIEgbC6uJwS5pjnPzIYreh7AtdgnrAJxVvmNI0-6cYRuK0AbEgnQziTry6J-S0RyorHo4-7b3b9x8Rn7pl5wI7TyAP7nvD4RAqpOnrn7HAf7X9NDw7QEDfmXzPquVWbuaOMzOEfDh-_DBpOGkOfkaCgYKAUYSARESFQHGX2Mii53-4bcjZLOXXxESdQZIsw0174")
  end
  let!(:migration_config) { create(:gdrive_migration_config, community: community) }
  subject(:job) { described_class.new }

  around do |example|
    Timecop.freeze(Time.zone.parse("2024-01-14 12:00")) do
      example.run
    end
  end

  describe "with webhook with expiration in > 2 days" do
    let(:expiration) { Time.current + 3.days }
    let!(:operation) do
      create(:gdrive_migration_operation, :webhook_registered, config: migration_config,
                                                               webhook_channel_id: "2b8d212d-b0f7-47ae-b5ec-e971d8f86c19",
                                                               webhook_expires_at: expiration,
                                                               start_page_token: "13296")
    end

    it "does not refresh" do
      # We have no cassette so if there are API calls the spec will fail
      perform_job
      operation.reload
      expect(operation.webhook_expires_at).to eq(expiration)
    end
  end

  describe "with webhook with expiration in the past" do
    let(:expiration) { Time.current - 1.day }
    let!(:operation) do
      create(:gdrive_migration_operation, :webhook_registered, config: migration_config,
                                                               webhook_channel_id: "0a6ba57a-e058-4a06-a21f-ae1e57f0262b",
                                                               webhook_expires_at: expiration,
                                                               start_page_token: "13296")
    end

    it "refreshes and ignores failure on stop call" do
      VCR.use_cassette("gdrive/migration/webhook_refresh_job/missing_existing_webhook") do
        perform_job
      end
      operation.reload
      expect(operation.webhook_expires_at).to eq(Time.current + 7.days)
    end
  end

  # For this spec, there should be an actual webhook setup with a matching
  # channel_id and resource_id
  describe "with webhook with expiration in < 2 days" do
    let(:expiration) { Time.current + 1.day }
    let!(:operation) do
      create(:gdrive_migration_operation, :webhook_registered, config: migration_config,
                                                               webhook_channel_id: "2b8d212d-b0f7-47ae-b5ec-e971d8f86c19",
                                                               webhook_resource_id: "030dP89w23Mzw28mQBrIu00iMXg",
                                                               webhook_expires_at: expiration)
    end

    it "refreshes" do
      VCR.use_cassette("gdrive/migration/webhook_refresh_job/happy_path") do
        perform_job
      end
      operation.reload
      expect(operation.webhook_expires_at).to eq(Time.current + 7.days)

      # We perturbed this value in the cassette response to ensure we're persisting whatever is returned
      expect(operation.webhook_resource_id).to eq("030dP89w23Mzw28mQBrIu00iMXz")
    end
  end
end
