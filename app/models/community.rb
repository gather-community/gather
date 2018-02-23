class Community < ApplicationRecord
  include CustomFields

  SLUG_REGEX = /[a-z][a-z\-]*/

  acts_as_tenant :cluster
  resourcify

  # The order of these matters for destruction.
  belongs_to :cluster, inverse_of: :communities
  has_many :meals, inverse_of: :community, dependent: :destroy
  has_many :meal_formulas, class_name: "Meals::Formula", inverse_of: :community, dependent: :destroy
  has_many :reservation_protocols, class_name: "Reservations::Protocol",
    inverse_of: :community, dependent: :destroy
  has_many :reservation_shared_guidelines, class_name: "Reservations::SharedGuidelines",
    inverse_of: :community, dependent: :destroy
  has_many :resources, class_name: "Reservations::Resource", inverse_of: :community, dependent: :destroy
  has_many :households, inverse_of: :community, dependent: :destroy
  has_many :wiki_pages, class_name: "Wiki::Page", inverse_of: :community, dependent: :destroy

  scope :by_name, -> { order("name") }
  scope :by_name_with_first, ->(c) { order("CASE WHEN communities.id = #{c.id} THEN 1 ELSE 2 END, name") }

  custom_fields :settings, spec: [
    {key: :time_zone, type: :time_zone, required: true, default: "UTC"},
    {key: :default_landing_page, type: :enum, options: %w(meals directory reservations wiki), default: "directory", required: true},
    {key: :meals, type: :group, fields: [
      {key: :reimb_instructions, type: :string},
      {key: :extra_roles, type: :string, default: "asst_cook, cleaner"},
      {key: :default_shift_times, type: :group, fields: [
        {key: :start, type: :group, fields: [
          {key: :head_cook, type: :integer, required: true, default: -195},
          {key: :asst_cook, type: :integer, required: true, default: -135},
          {key: :table_setter, type: :integer, required: true, default: -60},
          {key: :cleaner, type: :integer, required: true, default: 45}
        ]},
        {key: :end, type: :group, fields: [
          {key: :head_cook, type: :integer, required: true, default: 0},
          {key: :asst_cook, type: :integer, required: true, default: 0},
          {key: :table_setter, type: :integer, required: true, default: 0},
          {key: :cleaner, type: :integer, required: true, default: 165}
        ]}
      ]},
    ]},
    {key: :reservations, type: :group, fields: [
      {key: :kinds, type: :string},
      {key: :meals, type: :group, fields: [
        {key: :default_total_time, type: :integer, required: true, default: 330},
        {key: :default_prep_time, type: :integer, required: true, default: 180}
      ]}
    ]},
    {key: :billing, type: :group, fields: [
      {key: :payment_instructions, type: :text},
      {key: :statement_terms, type: :integer, default: 30},
      {key: :late_fee_policy, type: :group, fields: [
        {key: :fee_type, type: :enum, options: %w(none fixed percent), default: "none", required: true},
        {key: :threshold, type: :decimal},
        {key: :amount, type: :decimal}
      ]}
    ]}
  ]

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
end
