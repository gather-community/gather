# frozen_string_literal: true

# Methods allowing editing attachments via forms.
# Currently just for attribs named 'photo', but could/should be generalized.
module AttachmentFormable
  extend ActiveSupport::Concern

  included do
    attr_accessor :photo_destroy
    attr_reader :photo_new_signed_id

    validate :valid_attachment_content_types
    validate :valid_attachment_size

    before_save do
      photo.purge if photo_destroy? && photo.attached?
    end
  end

  class_methods do
    attr_accessor :attachment_content_types, :attachment_size_limits

    def validates_attachment_content_type(attrib, content_type:)
      self.attachment_content_types ||= {}
      attachment_content_types[attrib] = content_type
    end

    def validates_attachment_size(attrib, less_than:)
      self.attachment_size_limits ||= {}
      attachment_size_limits[attrib] = less_than
    end
  end

  def photo_new_signed_id=(signed_id)
    @photo_new_signed_id = signed_id
    self.photo = signed_id if signed_id.present?
  end

  def photo_destroy?
    photo_destroy.to_i == 1
  end

  def valid_attachment_content_types
    self.class.attachment_content_types.each do |attrib, types|
      next unless send(attrib).attached?
      next if types.include?(send(attrib).blob.content_type)
      errors.add(attrib, :invalid_content_type)
    end
  end

  def valid_attachment_size
    self.class.attachment_size_limits.each do |attrib, limit|
      next unless send(attrib).attached?
      next if send(attrib).blob.byte_size < limit
      errors.add(attrib, :too_big, max: limit / 1.megabyte)
    end
  end
end
