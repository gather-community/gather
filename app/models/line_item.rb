class LineItem < ActiveRecord::Base
  belongs_to :household
  belongs_to :invoice

  scope :incurred_between, ->(a,b){ where("incurred_on >= ? AND incurred_on <= ?", a, b) }
  scope :uninvoiced, ->{ where(invoice_id: nil) }
  scope :credit, ->{ where("amount < 0") }
  scope :charge, ->{ where("amount > 0") }
end
