# frozen_string_literal: true

# == Schema Information
#
# Table name: gdrive_migration_logs
#
#  id           :bigint           not null, primary key
#  cluster_id   :bigint           not null
#  created_at   :datetime         not null
#  data         :jsonb
#  level        :string           not null
#  message      :text             not null
#  operation_id :bigint           not null
#
require "rails_helper"

describe GDrive::Migration::Log do
  it "has a valid factory" do
    log = create(:gdrive_migration_log)
    expect(log.data).to eq({"foo" => "bar"})
  end
end
