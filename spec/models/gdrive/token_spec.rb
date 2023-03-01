# frozen_string_literal: true

require "rails_helper"

describe GDrive::Token do
  it "has a valid factory" do
    create(:gdrive_token)
  end
end
