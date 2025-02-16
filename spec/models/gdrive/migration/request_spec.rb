# frozen_string_literal: true

require "rails_helper"

describe GDrive::Migration::Request do
  it "has a valid factory" do
    create(:gdrive_migration_request)
  end
end
