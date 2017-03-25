class Community < ActiveRecord::Base
  include CustomFields

  resourcify

  belongs_to :cluster, inverse_of: :communities

  scope :by_name, -> { order("name") }
  scope :by_name_with_first, ->(c) { order("CASE WHEN communities.id = #{c.id} THEN 1 ELSE 2 END, name") }

  serialize :settings

  custom_fields :config, spec: [
    {key: "reminder_time_of_day", type: "integer", required: true}
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
