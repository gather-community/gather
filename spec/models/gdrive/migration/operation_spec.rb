# frozen_string_literal: true

require "rails_helper"

describe GDrive::Migration::Operation do
  it "has a valid factory" do
    create(:gdrive_migration_operation)
  end
end
