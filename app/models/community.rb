# frozen_string_literal: true

# This is what it's all about!
class Community < ApplicationRecord
  include CustomFields
  include SemicolonDisallowable

  SLUG_REGEX = /[a-z][a-z-]*/

  acts_as_tenant :cluster
  resourcify

  # The order of these matters for destruction.
  belongs_to :cluster, inverse_of: :communities
  has_many :billing_templates, class_name: "Billing::Template", inverse_of: :community, dependent: :destroy
  has_many :group_affiliations, class_name: "Groups::Affiliation", inverse_of: :community, dependent: :destroy
  has_many :meals, class_name: "Meals::Meal", inverse_of: :community, dependent: :destroy
  has_many :meal_formulas, class_name: "Meals::Formula", inverse_of: :community, dependent: :destroy
  has_many :meal_restrictions, class_name: "Meals::Restriction", inverse_of: :community, dependent: :destroy
  has_many :meal_roles, class_name: "Meals::Role", inverse_of: :community, dependent: :destroy
  has_many :meal_types, class_name: "Meals::Type", inverse_of: :community, dependent: :destroy
  has_many :member_types, class_name: "People::MemberType", inverse_of: :community, dependent: :destroy
  has_many :calendar_protocols, class_name: "Calendars::Protocol",
    inverse_of: :community, dependent: :destroy
  has_many :calendar_shared_guidelines, class_name: "Calendars::SharedGuidelines",
    inverse_of: :community, dependent: :destroy
  has_many :calendars, class_name: "Calendars::Calendar", inverse_of: :community, dependent: :destroy
  has_many :calendar_groups, class_name: "Calendars::Group", inverse_of: :community, dependent: :destroy
  has_many :households, inverse_of: :community, dependent: :destroy
  has_many :wiki_pages, class_name: "Wiki::Page", inverse_of: :community, dependent: :destroy
  has_one :subscription, inverse_of: :community, class_name: "Subscription::Subscription", dependent: :destroy
  has_one :subscription_intent, inverse_of: :community, class_name: "Subscription::Intent", dependent: :destroy
  has_many :work_periods, class_name: "Work::Period", inverse_of: :community, dependent: :destroy

  scope :by_name, -> { order(:name) }
  scope :by_one_cmty_first, ->(c) { order(arel_table[:id].not_eq(c.id)) }
  scope :by_name_with_first, ->(c) { by_one_cmty_first(c).by_name }

  disallow_semicolons :name

  delegate :name, to: :cluster, prefix: true

  before_create :generate_calendar_token
  before_create :generate_sso_secret

  custom_fields :settings, spec: lambda { |_cmty|
    [
      {key: :time_zone, type: :time_zone, required: true, default: "UTC"},
      {key: :default_landing_page, type: :enum, options: %w[meals directory calendars wiki],
       default: "directory", required: true},
      {key: :main_nav_customizations, type: :text},
      {key: :people, type: :group, fields: [
        {key: :default_directory_sort, type: :enum, options: %w[name unit], default: "name", required: true},
        {key: :plain_user_selects, type: :boolean, default: false},
        {key: :user_custom_fields_spec, type: :spec}
      ]},
      {key: :meals, type: :group, fields: [
        {key: :reimb_instructions, type: :markdown},
        {key: :allergens, type: :text, required: true, default: "Dairy, Shellfish, Soy, Nuts"},
        {key: :default_capacity, type: :integer, required: true, default: 50},
        {key: :show_reimb_form, type: :boolean, default: false},
        {key: :cooks_can_finalize, type: :boolean, default: false},
        {key: :cooks_can_change_invites, type: :boolean, default: false},
        {key: :default_invites, type: :enum, options: %w[all own], default: "all", required: true},
        {key: :allow_job_signup_on_meal_page, type: :boolean, default: true},
        {key: :reminder_lead_times, type: :group, fields: [
          {key: :diner, type: :integer, required: true, default: 0},
          {key: :early_menu, type: :integer, required: true, default: 10},
          {key: :late_menu, type: :integer, required: true, default: 5}
        ]}
      ]},
      {key: :calendars, type: :group, fields: [
        {key: :kinds, type: :string},
        {key: :meals, type: :group, fields: [
          {key: :default_total_time, type: :integer, required: true, default: 330},
          {key: :default_prep_time, type: :integer, required: true, default: 180}
        ]}
      ]},
      {key: :work, type: :group, fields: [
        {key: :default_date_filter, type: :enum, options: %w[all curftr], default: "all", required: true}
      ]},
      {key: :billing, type: :group, fields: [
        {key: :contact, type: :email},
        {key: :statement_terms, type: :integer, default: 30},
        {key: :statement_reminder_lead_time, type: :integer, required: true, default: 5},
        {key: :paypal_reimbursement, type: :boolean, default: false},
        {key: :payment_methods, type: :group, fields: [
          {key: :paypal_me, type: :url, host: "paypal.me"},
          {key: :paypal_email, type: :email},
          {key: :paypal_friend, type: :boolean, default: true},
          {key: :check_payee, type: :string},
          {key: :check_address, type: :text},
          {key: :check_dropoff, type: :string},
          {key: :cash_dropoff, type: :string},
          {key: :additional_info, type: :markdown},
          {key: :show_billing_contact, type: :boolean, default: true}
        ]},
        {key: :late_fee_policy, type: :group, fields: [
          {key: :fee_type, type: :enum, options: %w[none fixed percent], default: "none", required: true},
          {key: :threshold, type: :decimal},
          {key: :amount, type: :decimal}
        ]}
      ]}
    ]
  }

  def self.multiple?
    count > 1
  end

  # Satisfies a policy duck type.
  def community
    self
  end

  # Destroys all community records except those related to the given households
  def clean_out_except(hholds_to_save)
    assocs = self.class.reflect_on_all_associations.select(&:collection?).map(&:name) - [:households]
    assocs.each { |a| send(a).destroy_all }
    (households - Array.wrap(hholds_to_save)).each(&:destroy)
  end

  def subdomain
    slug
  end

  def lc_abbrv
    abbrv.downcase
  end

  private

  def generate_calendar_token
    self.calendar_token ||= UniqueTokenGenerator.generate(self.class, :calendar_token)
  end

  def generate_sso_secret
    self.sso_secret ||= UniqueTokenGenerator.generate(self.class, :sso_secret, type: :hex32)
  end
end
