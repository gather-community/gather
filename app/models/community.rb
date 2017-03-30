class Community < ActiveRecord::Base
  include CustomFields

  resourcify

  belongs_to :cluster, inverse_of: :communities

  scope :by_name, -> { order("name") }
  scope :by_name_with_first, ->(c) { order("CASE WHEN communities.id = #{c.id} THEN 1 ELSE 2 END, name") }

  serialize :settings

  custom_fields :config, spec: [
    {key: :meals, type: :group, fields: [
      {key: :reimb_instructions, type: :string},
      {key: :admin_email, type: :email},
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
        {key: :default_length, type: :integer, required: true, default: 330},
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

  def self.find_by_abbrv(abbrv)
    where("LOWER(abbrv) = ?", abbrv.downcase).first
  end

  def self.multiple?
    count > 1
  end

  # Satisfies a policy duck type.
  def community
    self
  end

  def lc_abbrv
    abbrv.downcase
  end
end
