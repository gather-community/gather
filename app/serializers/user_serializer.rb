# frozen_string_literal: true

# == Schema Information
#
# Table name: users
#
#  id                     :integer          not null, primary key
#  allergies              :string
#  alternate_id           :string
#  birthdate              :date
#  calendar_token         :string
#  child                  :boolean          default(FALSE), not null
#  cluster_id             :integer          not null
#  confirmation_sent_at   :datetime
#  confirmation_token     :string
#  confirmed_at           :datetime
#  created_at             :datetime         not null
#  current_sign_in_at     :datetime
#  current_sign_in_ip     :inet
#  custom_data            :jsonb            not null
#  deactivated_at         :datetime
#  doctor                 :string
#  email                  :string(255)
#  encrypted_password     :string           default(""), not null
#  fake                   :boolean          default(FALSE), not null
#  first_name             :string           not null
#  full_access            :boolean          default(TRUE), not null
#  google_email           :string(255)
#  home_phone             :string
#  household_id           :integer          not null
#  job_choosing_proxy_id  :integer
#  joined_on              :date
#  last_name              :string           not null
#  last_sign_in_at        :datetime
#  last_sign_in_ip        :inet
#  medical                :text
#  mobile_phone           :string
#  paypal_email           :string(255)
#  preferred_contact      :string
#  privacy_settings       :jsonb            not null
#  pronouns               :string(24)
#  provider               :string
#  remember_created_at    :datetime
#  remember_token         :string
#  reset_password_sent_at :datetime
#  reset_password_token   :string
#  school                 :string
#  settings               :jsonb            not null
#  sign_in_count          :integer          default(0), not null
#  uid                    :string
#  unconfirmed_email      :string(255)
#  updated_at             :datetime         not null
#  work_phone             :string
#
class UserSerializer < ApplicationSerializer
  attributes :id, :name

  def name
    object.full_name(show_inactive: !instance_options[:hide_inactive_in_name])
  end
end
