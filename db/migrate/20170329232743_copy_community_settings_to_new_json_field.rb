# frozen_string_literal: true

class Community < ApplicationRecord
  serialize :settings
end

class CopyCommunitySettingsToNewJsonField < ActiveRecord::Migration[4.2]
  def up
    ActsAsTenant.without_tenant do
      Community.all.each do |community|
        old_settings = community.settings
        community.send(:write_attribute, :config,
                       meals: {
                         reimb_instructions: "Place " << old_settings[:meal_reimb_dropoff_loc],
                         admin_email: old_settings[:meals_ctte_email],
                         extra_roles: "asst_cook, cleaner" << (old_settings[:has_table_setters] ? ", table_setter" : ""),
                         default_shift_times: {
                           start: {
                             head_cook: -195,
                             asst_cook: -135,
                             table_setter: -60,
                             cleaner: 45
                           },
                           end: {
                             head_cook: 0,
                             asst_cook: 0,
                             table_setter: 0,
                             cleaner: 165
                           }
                         }
                       },
                       reservations: {
                         kinds: old_settings[:reservation_kinds].try(:join, ", "),
                         meals: {
                           default_total_time: 330,
                           default_prep_time: 180
                         }
                       },
                       billing: {
                         payment_instructions: old_settings[:payment_instructions],
                         statement_terms: old_settings[:statement_terms],
                         late_fee_policy: {
                           fee_type: old_settings[:late_fee_policy].try(:[], :fee_type),
                           threshold: old_settings[:late_fee_policy].try(:[], :threshold),
                           amount: old_settings[:late_fee_policy].try(:[], :fee_amount)
                         }
                       })
        community.save!
      end
    end
  end
end
