module Reservation
  class Resource < ActiveRecord::Base
    self.table_name = "resources"

    belongs_to :community

    has_attached_file :photo,
      styles: { thumb: "160x120#" },
      default_url: "/images/missing/:style.png"
    validates_attachment_content_type :photo, content_type: /\Aimage\/jpeg/
    validates_attachment_file_name :photo, matches: /jpe?g\Z/i
  end
end