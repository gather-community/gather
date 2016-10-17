class Community < ActiveRecord::Base
  resourcify

  scope :by_name, -> { order("name") }
  scope :by_name_with_first, ->(c) { order("CASE WHEN communities.id = #{c.id} THEN 1 ELSE 2 END, name") }

  serialize :settings

  def self.find_by_abbrv(abbrv)
    where("LOWER(abbrv) = ?", abbrv.downcase).first
  end

  def self.multiple?
    count > 1
  end

  def lc_abbrv
    abbrv.downcase
  end
end
