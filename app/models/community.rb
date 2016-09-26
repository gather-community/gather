class Community < ActiveRecord::Base
  resourcify

  scope :by_name, -> { order("name") }

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
