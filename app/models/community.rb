# frozen_string_literal: true

# == Schema Information
#
# Table name: communities
#
#  id             :integer          not null, primary key
#  abbrv          :string(2)
#  calendar_token :string           not null
#  cluster_id     :integer          not null
#  country_code   :string(2)        default("US"), not null
#  created_at     :datetime         not null
#  name           :string(20)       not null
#  settings       :jsonb
#  slug           :string           not null
#  sso_secret     :string           not null
#  updated_at     :datetime         not null
#
# This is what it's all about!
class Community < ApplicationRecord
  include CustomFields
  include Deactivatable
  include SemicolonDisallowable

  SLUG_REGEX = /[a-z][a-z-]*/
  SLUG_MAX_LENGTH = 63
  STATUSES = %i[trial subscribed problem warning deactivated].freeze

  # Maps an ISO 3166-1 alpha-2 country code (uppercase) to its default ISO 4217 currency
  # (lowercase, to match Stripe and the money gem). Covers Stripe-supported countries;
  # extend as Stripe adds markets. Source: https://stripe.com/global
  COUNTRY_CURRENCIES = {
    "AE" => "aed", "AT" => "eur", "AU" => "aud", "BE" => "eur", "BG" => "bgn",
    "BR" => "brl", "CA" => "cad", "CH" => "chf", "CY" => "eur", "CZ" => "czk",
    "DE" => "eur", "DK" => "dkk", "EE" => "eur", "ES" => "eur", "FI" => "eur",
    "FR" => "eur", "GB" => "gbp", "GI" => "gbp", "GR" => "eur", "HK" => "hkd",
    "HR" => "eur", "HU" => "huf", "ID" => "idr", "IE" => "eur", "IN" => "inr",
    "IT" => "eur", "JP" => "jpy", "LI" => "chf", "LT" => "eur", "LU" => "eur",
    "LV" => "eur", "MT" => "eur", "MX" => "mxn", "MY" => "myr", "NL" => "eur",
    "NO" => "nok", "NZ" => "nzd", "PL" => "pln", "PT" => "eur", "RO" => "ron",
    "SE" => "sek", "SG" => "sgd", "SI" => "eur", "SK" => "eur", "TH" => "thb",
    "US" => "usd"
  }.freeze

  acts_as_tenant :cluster
  resourcify

  encrypts :sso_secret
  encrypts :calendar_token

  # The order of these matters for destruction. See comments below.
  belongs_to :cluster, inverse_of: :communities
  has_many :billing_templates, class_name: "Billing::Template", inverse_of: :community, dependent: :destroy
  has_many :messaging_accounts, class_name: "Messaging::Account", inverse_of: :community, dependent: :destroy
  has_many :group_affiliations, class_name: "Groups::Affiliation", inverse_of: :community, dependent: :destroy
  has_many :domain_ownerships, class_name: "DomainOwnership", inverse_of: :community, dependent: :destroy
  has_many :meals, class_name: "Meals::Meal", inverse_of: :community, dependent: :destroy
  has_many :meal_formulas, class_name: "Meals::Formula", inverse_of: :community, dependent: :destroy
  has_many :meal_roles, class_name: "Meals::Role", inverse_of: :community, dependent: :destroy
  has_many :meal_types, class_name: "Meals::Type", inverse_of: :community, dependent: :destroy
  has_many :meal_imports, class_name: "Meals::Import", inverse_of: :community, dependent: :destroy
  has_many :calendar_protocols, class_name: "Calendars::Protocol",
    inverse_of: :community, dependent: :destroy
  has_many :calendar_shared_guidelines, class_name: "Calendars::SharedGuidelines",
    inverse_of: :community, dependent: :destroy
  has_many :calendars, class_name: "Calendars::Calendar", inverse_of: :community, dependent: :destroy
  has_many :calendar_groups, class_name: "Calendars::Group", inverse_of: :community, dependent: :destroy
  # Wiki pages must be destroyed before households because wiki_pages/wiki_page_versions have FKs to users.
  has_many :wiki_pages, class_name: "Wiki::Page", inverse_of: :community, dependent: :destroy
  # Households must be destroyed before member_types because households.member_type_id has a FK constraint.
  has_many :households, inverse_of: :community, dependent: :destroy
  has_many :member_types, class_name: "People::MemberType", inverse_of: :community, dependent: :destroy
  has_one :subscription, inverse_of: :community, class_name: "Subscription::Subscription", dependent: :destroy
  has_one :subscription_intent, inverse_of: :community, class_name: "Subscription::Intent",
    dependent: :destroy
  has_one :messaging_topup, inverse_of: :community, class_name: "Subscription::MessagingTopup",
    dependent: :destroy
  has_many :work_periods, class_name: "Work::Period", inverse_of: :community, dependent: :destroy
  has_one :gdrive_config, class_name: "GDrive::Config", inverse_of: :community, dependent: :destroy
  has_one :gdrive_migration_operation, class_name: "GDrive::Migration::Operation", inverse_of: :community,
    dependent: :destroy
  has_many :restrictions, class_name: "Meals::Restriction", inverse_of: :community, dependent: :destroy

  scope :by_name, -> { order(:name) }
  scope :by_one_cmty_first, ->(c) { order(arel_table[:id].not_eq(c.id)) }
  scope :by_name_with_first, ->(c) { by_one_cmty_first(c).by_name }

  accepts_nested_attributes_for :restrictions

  validates :slug, length: {maximum: SLUG_MAX_LENGTH}

  disallow_semicolons :name

  delegate :name, to: :cluster, prefix: true

  # Country codes are ISO 3166-1 alpha-2 and must be stored uppercase so lookups
  # (e.g. Messaging::Account currency selection) are reliable.
  before_validation { self.country_code = country_code&.upcase }

  before_create :generate_calendar_token
  before_create :generate_sso_secret
  # Capture affiliated group IDs before the cascade destroys group_affiliations so we can
  # destroy groups that end up with no remaining community affiliations (orphaned groups).
  # prepend: true ensures this runs before the has_many :group_affiliations dependent: :destroy.
  before_destroy :cache_affiliated_group_ids, prepend: true
  after_destroy :destroy_orphaned_groups

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
      {key: :restrictions, type: :group, fields: [
        {key: :restriction, type: :integer}
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

  # The per-community "Deleted Member" placeholder user. Records authored by a deleted member
  # (meals, wiki pages, calendar events) are reassigned to this user so community history
  # survives anonymized. Created lazily on first deletion — never seeded — so a fresh community
  # has no placeholder (keeps the "no sample data" generator invariants intact). It lives in its
  # own deactivated placeholder household and is excluded from directories, selects, etc.
  def deleted_member
    households.find_by(deleted_placeholder: true)&.users&.first || create_deleted_member
  end

  def subdomain
    slug
  end

  def lc_abbrv
    abbrv.downcase
  end

  # The default currency for the community's country, or nil if unsupported.
  def default_currency
    COUNTRY_CURRENCIES[country_code]
  end

  # The community's single messaging wallet, or nil if it has never been funded. There is at most
  # one (unique index on messaging_accounts.community_id).
  def messaging_account
    messaging_accounts.first
  end

  def status
    if inactive?
      :deactivated
    elsif inactivity_warning_count > 0
      :warning
    elsif subscription_problem?
      :problem
    elsif subscription_subscribed?
      :subscribed
    else
      :trial
    end
  end

  # The subscription's detailed_status, computed from either the CommunitySummarizer's virtual
  # attributes (index context, no N+1) or the loaded subscription association. Returns :unknown
  # when there is no subscription.
  def subscription_detailed_status
    Subscription::Subscription.derive_detailed_status(
      stripe_status: subscription_signal(:stripe_status),
      payment_intent_status: subscription_signal(:payment_intent_status),
      payment_intent_next_action_type: subscription_signal(:payment_intent_next_action_type),
      setup_intent_status: subscription_signal(:setup_intent_status),
      setup_intent_next_action_type: subscription_signal(:setup_intent_next_action_type),
      synced_at: subscription_signal(:synced_at)
    )
  end

  def subscription_present?
    if has_attribute?("subscription_stripe_id")
      self["subscription_stripe_id"].present?
    else
      subscription.present?
    end
  end

  def subscription_subscribed?
    subscription_present? &&
      Subscription::Subscription::GOOD_STANDING_STATUSES.include?(subscription_detailed_status)
  end

  def subscription_problem?
    subscription_present? &&
      Subscription::Subscription::PROBLEM_STATUSES.include?(subscription_detailed_status)
  end

  private

  # Deactivated ⇒ email is not required and it's excluded from active-scoped lists for free.
  # Rescues a unique-index race (two concurrent deletions) by re-reading the winner's row.
  def create_deleted_member
    household = households.create!(name: "Deleted Members", deleted_placeholder: true)
    household.users.create!(deleted_placeholder: true, first_name: "Deleted", last_name: "Member",
      child: false, deactivated_at: Time.current)
  rescue ActiveRecord::RecordNotUnique
    households.find_by(deleted_placeholder: true).users.first
  end

  # Reads a subscription signal from the summarizer's virtual attribute (aliased as
  # subscription_<name>) when present, else from the loaded subscription association.
  def subscription_signal(name)
    key = "subscription_#{name}"
    if has_attribute?(key)
      self[key]
    else
      subscription&.public_send(name)
    end
  end

  def generate_calendar_token
    self.calendar_token ||= UniqueTokenGenerator.generate(self.class, :calendar_token)
  end

  def generate_sso_secret
    self.sso_secret ||= UniqueTokenGenerator.generate(self.class, :sso_secret, type: :hex32)
  end

  def cache_affiliated_group_ids
    @affiliated_group_ids = group_affiliations.pluck(:group_id)
  end

  def destroy_orphaned_groups
    Groups::Group.where(id: @affiliated_group_ids).find_each do |group|
      group.destroy! if group.affiliations.none?
    end
  end
end
