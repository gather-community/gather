# frozen_string_literal: true

# Methods allowing editing attachments via forms.
# Currently just for attribs named 'photo', but could/should be generalized.
module AttachmentFormable
  extend ActiveSupport::Concern

  included do
    attr_accessor :photo_destroy
    attr_reader :photo_new_signed_id

    before_save do
      photo.destroy if photo_destroy? && photo.attached?
    end
  end

  def photo_new_signed_id=(signed_id)
    @photo_new_signed_id = signed_id
    self.photo = signed_id if signed_id.present?
  end

  def photo_destroy?
    photo_destroy.to_i == 1
  end
end
