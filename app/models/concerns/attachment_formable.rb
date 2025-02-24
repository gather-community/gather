# frozen_string_literal: true

# Methods allowing editing attachments via forms.
module AttachmentFormable
  extend ActiveSupport::Concern

  included do
    before_save :destroy_attachments_if_requested
  end

  class_methods do
    attr_accessor :attachment_attribs

    def accepts_attachment_via_form(*attribs)
      self.attachment_attribs ||= []

      attribs.each do |attrib|
        attachment_attribs << attrib

        attr_accessor(:"#{attrib}_destroy")
        attr_reader(:"#{attrib}_new_signed_id")

        define_method(:"#{attrib}_new_signed_id=") do |signed_id|
          instance_variable_set("@#{attrib}_new_signed_id", signed_id)
          send("#{attrib}=", signed_id) if signed_id.present?
        end

        define_method(:"#{attrib}_destroy?") do
          send("#{attrib}_destroy")&.to_i == 1
        end
      end
    end
  end

  private

  def destroy_attachments_if_requested
    return if self.class.attachment_attribs.blank?

    self.class.attachment_attribs.each do |attrib|
      attachment = send(attrib)
      attachment.purge if send("#{attrib}_destroy?") && attachment.attached?
    end
  end
end
