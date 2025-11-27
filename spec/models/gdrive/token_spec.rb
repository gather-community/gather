# frozen_string_literal: true

# == Schema Information
#
# Table name: gdrive_tokens
#
#  id               :bigint           not null, primary key
#  cluster_id       :bigint           not null
#  created_at       :datetime         not null
#  data             :text             not null
#  gdrive_config_id :bigint           not null
#  google_user_id   :string           not null
#  updated_at       :datetime         not null
#
require "rails_helper"

describe GDrive::Token do
  it "has a valid factory" do
    create(:gdrive_token)
  end
end
