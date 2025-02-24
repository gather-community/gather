# == Schema Information
#
# Table name: mail_test_runs
#
#  id           :bigint           not null, primary key
#  counter      :integer          default(0)
#  mail_sent_at :datetime
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
class MailTestRun < ApplicationRecord
end
