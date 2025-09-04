# frozen_string_literal: true

# == Schema Information
#
# Table name: work_shares
#
#  id         :bigint           not null, primary key
#  cluster_id :integer          not null
#  created_at :datetime         not null
#  period_id  :integer          not null
#  portion    :decimal(4, 3)    default(1.0), not null
#  priority   :boolean          default(FALSE), not null
#  updated_at :datetime         not null
#  user_id    :integer          not null
#
FactoryBot.define do
  factory :work_share, class: "Work::Share" do
    association :period, factory: :work_period
    user
    portion { 1.0 }
  end
end
