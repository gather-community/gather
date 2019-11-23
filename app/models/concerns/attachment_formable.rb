# frozen_string_literal: true

# Methods allowing editing attachments via forms.
module AttachmentFormable
  extend ActiveSupport::Concern

  included do
    validate :valid_attachment_content_types
    validate :valid_attachment_size
    before_save :destroy_attachments_if_requested
  end

  class_methods do
    attr_accessor :attachment_attribs, :attachment_content_types, :attachment_size_limits

    def accepts_attachment_via_form(*attribs)
      self.attachment_attribs ||= []

      attribs.each do |attrib|
        attachment_attribs << attrib

        attr_accessor :"#{attrib}_destroy"
        attr_reader :"#{attrib}_new_signed_id"

        define_method(:"#{attrib}_new_signed_id=") do |signed_id|
          instance_variable_set("@#{attrib}_new_signed_id", signed_id)
          send("#{attrib}=", signed_id) if signed_id.present?
        end

        define_method(:"#{attrib}_destroy?") do
          send("#{attrib}_destroy")&.to_i == 1
        end
      end
    end

    def validates_attachment_content_type(attrib, content_type:)
      self.attachment_content_types ||= {}
      attachment_content_types[attrib] = content_type
    end

    def validates_attachment_size(attrib, less_than:)
      self.attachment_size_limits ||= {}
      attachment_size_limits[attrib] = less_than
    end
  end

  private

  def valid_attachment_content_types
    (self.class.attachment_content_types || {}).each do |attrib, types|
      next unless send(attrib).attached?
      next if types.include?(send(attrib).blob.content_type)
      errors.add(attrib, :invalid_content_type)
    end
  end

  def valid_attachment_size
    (self.class.attachment_size_limits || {}).each do |attrib, limit|
      next unless send(attrib).attached?
      next if send(attrib).blob.byte_size < limit
      errors.add(attrib, :too_big, max: limit / 1.megabyte)
    end
  end

  def destroy_attachments_if_requested
    self.class.attachment_attribs.each do |attrib|
      attachment = send(attrib)
      attachment.purge if send("#{attrib}_destroy?") && attachment.attached?
    end
  end
end
