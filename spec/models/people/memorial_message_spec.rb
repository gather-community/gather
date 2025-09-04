# frozen_string_literal: true

# == Schema Information
#
# Table name: people_memorial_messages
#
#  id          :bigint           not null, primary key
#  author_id   :bigint           not null
#  body        :text             not null
#  cluster_id  :bigint
#  created_at  :datetime         not null
#  memorial_id :bigint           not null
#  updated_at  :datetime         not null
#
require "rails_helper"

describe People::MemorialMessage do
  it "has valid factory" do
    create(:memorial_message)
  end
end
