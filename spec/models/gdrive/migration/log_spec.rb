# frozen_string_literal: true

require "rails_helper"

describe GDrive::Migration::Log do
  it "has a valid factory" do
    log = create(:gdrive_migration_log)
    expect(log.data).to eq({"foo" => "bar"})
  end
end
