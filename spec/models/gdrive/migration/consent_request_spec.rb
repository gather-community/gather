# frozen_string_literal: true

require "rails_helper"

describe GDrive::Migration::ConsentRequest do
  it "has a valid factory" do
    create(:gdrive_migration_consent_request)
  end
end
