# frozen_string_literal: true

# == Schema Information
#
# Table name: people_memorials
#
#  id         :bigint           not null, primary key
#  birth_year :integer
#  cluster_id :bigint           not null
#  created_at :datetime         not null
#  death_year :integer          not null
#  obituary   :text
#  updated_at :datetime         not null
#  user_id    :bigint           not null
#
require "rails_helper"

describe People::Memorial do
  it "has valid factory" do
    create(:memorial)
  end
end
