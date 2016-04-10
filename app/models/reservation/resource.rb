module Reservation
  class Resource < ActiveRecord::Base
    self.table_name = "resources"

    belongs_to :community
    has_and_belongs_to_many :shared_guidelines,
      class_name: "Reservation::SharedGuidelines",
      join_table: "reservation_guideline_inclusions"

    has_attached_file :photo,
      styles: { thumb: "160x120#" },
      default_url: "/images/missing/:style.png"
    validates_attachment_content_type :photo, content_type: /\Aimage\/jpeg/
    validates_attachment_file_name :photo, matches: /jpe?g\Z/i

    def full_name
      "#{community.abbrv} #{name}"
    end

    def kinds
      community.settings[:reservation_kinds]
    end

    def has_guidelines?
      all_guidelines.present?
    end

    # Concatenates own guidelines and shared guidelines together
    # Returns empty string if no guidelines.
    def all_guidelines
      return @all_guidelines if @all_guidelines

      own = guidelines.blank? ? nil : guidelines
      shared = shared_guidelines.map(&:body)
      all = ([own] + shared).compact.map(&:strip)
      @all_guidelines = all.join("\n\n---\n\n")
    end
  end
end