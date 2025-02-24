# frozen_string_literal: true

class UploadsController < ApplicationController
  PERMITTED_ATTRIBS = {
    "User" => "photo",
    "Calendars::Calendar" => "photo",
    "Meals::Import" => "file"
  }.freeze

  before_action :ensure_permitted_class

  # Accepts uploaded files and stores them as Blobs, returning the signed_id for use in forms.
  # Checks validation errors on model and returns if found, but doesn't save model.
  def create
    authorize(Upload.new)
    blob = ActiveStorage::Blob.create_and_upload!(io: params[:file].open,
                                                  filename: params[:file].original_filename)

    # Run validations to ensure that the attachment is valid.
    object = build_object_with_blob_attached(params[:class_name], params[:attrib], blob)
    object.valid?
    if (errors = object.errors[params[:attrib]]).any?
      render(json: {error: errors}, status: :unprocessable_entity)
    else
      render(json: {blob_id: blob.signed_id}, status: :created)
    end
  end

  private

  def build_object_with_blob_attached(class_name, attrib, blob)
    object = class_name.constantize.new

    # If we don't set this, we get a custom field error.
    object.build_household(community: current_community) if class_name == "User"

    object.assign_attributes(attrib => blob.signed_id)
    object
  end

  def ensure_permitted_class
    return if Array.wrap(PERMITTED_ATTRIBS[params[:class_name]]).include?(params[:attrib])

    render(json: {error: ["Unpermitted attribute"]}, status: :forbidden)
  end
end
