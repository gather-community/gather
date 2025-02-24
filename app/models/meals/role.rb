# frozen_string_literal: true

module Meals
# == Schema Information
#
# Table name: meal_roles
#
#  id                     :bigint           not null, primary key
#  count_per_meal         :integer          default(1), not null
#  deactivated_at         :datetime
#  description            :text             not null
#  double_signups_allowed :boolean          default(FALSE)
#  shift_end              :integer
#  shift_start            :integer
#  special                :string(32)
#  time_type              :string(32)       default("date_time"), not null
#  title                  :string(128)      not null
#  work_hours             :decimal(6, 2)
#  work_job_title         :string(128)
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  cluster_id             :integer          not null
#  community_id           :integer          not null
#
# Indexes
#
#  index_meal_roles_on_cluster_id                             (cluster_id)
#  index_meal_roles_on_cluster_id_and_community_id_and_title  (cluster_id,community_id,title) WHERE (deactivated_at IS NULL)
#
# Foreign Keys
#
#  fk_rails_...  (cluster_id => clusters.id)
#  fk_rails_...  (community_id => communities.id)
#
  # Meal roles are types of jobs for meals like head cook, assistant cook, etc.
  class Role < ApplicationRecord
    include Wisper.model
    include Deactivatable
    include SemicolonDisallowable

    TIMES_OPTIONS = %i[date_time date_only].freeze

    acts_as_tenant :cluster

    belongs_to :community
    has_many :assignments, class_name: "Meals::Assignment", foreign_key: :role_id, inverse_of: :role
    has_many :reminders, -> { canonical_order }, class_name: "Meals::RoleReminder", dependent: :destroy,
                                                 foreign_key: :role_id, inverse_of: :role
    has_many :formula_roles, inverse_of: :role
    has_many :formulas, through: :formula_roles
    has_many :work_meal_job_sync_settings, class_name: "Work::MealJobSyncSetting", inverse_of: :role,
                                           dependent: :destroy

    scope :by_title, -> { order(arel_table[:special].not_eq("head_cook")).alpha_order(:title) }
    scope :in_community, ->(c) { where(community_id: c.id) }
    scope :head_cook, -> { where(special: "head_cook") }

    normalize_attributes :title, :description, :work_job_title

    before_validation :normalize

    validates :title, presence: true, length: {maximum: 128},
                      uniqueness: {scope: %i[community_id deactivated_at]}
    validates :count_per_meal, presence: true
    validates :time_type, presence: true
    validates :description, presence: true
    validates :shift_start, presence: true, if: :date_time?
    validates :shift_end, presence: true, if: :date_time?
    validate :shift_time_positive

    disallow_semicolons :title

    accepts_nested_attributes_for :reminders, reject_if: :all_blank, allow_destroy: true

    def head_cook?
      special == "head_cook"
    end

    def date_time?
      time_type == "date_time"
    end

    private

    def normalize
      if date_time?
        if shift_end.present? && shift_start.present?
          self.work_hours = (shift_end - shift_start).to_f / 60
        else
          self.work_hours = nil
        end
      else
        self.shift_start = nil
        self.shift_end = nil
      end
      self.count_per_meal = 1 if head_cook?
    end

    # Sets a validation message on shift_end if shift_start and shift_end are given and
    # and the resulting elapsed time is not positive. This would also raise an error on hours
    # but if these are set, hours is not visible.
    def shift_time_positive
      return unless shift_start.present? && shift_end.present? && !(shift_end - shift_start).positive?
      errors.add(:shift_end, :not_after_start)
    end
  end
end
