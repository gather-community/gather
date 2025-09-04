# frozen_string_literal: true

# == Schema Information
#
# Table name: mail_test_runs
#
#  id           :bigint           not null, primary key
#  counter      :integer          default(0)
#  created_at   :datetime         not null
#  mail_sent_at :datetime
#  updated_at   :datetime         not null
#
require "rails_helper"

describe MailTestRun do
  it "has a valid factory" do
    create(:mail_test_run)
  end
end
