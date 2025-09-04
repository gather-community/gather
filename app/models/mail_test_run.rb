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
class MailTestRun < ApplicationRecord
end
