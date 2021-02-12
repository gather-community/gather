# frozen_string_literal: true

class UploadsController < ApplicationController
  PERMITTED_ATTRIBS = {
    "User" => "photo",
    "Reservations::Resource" => "photo",
    "Meals::Import" => "file"
  }.freeze

  before_action :ensure_permitted_class

  # Accepts uploaded files and stores them as Blobs, returning the signed_id for use in forms.
  # Checks validation errors on model and returns if found, but doesn't save model.
  def create
    authorize(Upload.new)
    blob = ActiveStorage::Blob.create_after_upload!(io: params[:file].open,
                                                    filename: params[:file].original_filename)

    # Run validations to ensure that the attachment is valid.
    # A community is required for some validations so we provide one.
    object = params[:class_name].constantize.new(
      params[:attrib] => blob.signed_id,
      household: Household.new(community: current_community)
    ).tap(&:valid?)

    if (errors = object.errors[params[:attrib]]).any?
      render(json: {error: errors}, status: :unprocessable_entity)
    else
      render(json: {blob_id: blob.signed_id}, status: :created)
    end
  end

  private

  def ensure_permitted_class
    return if Array.wrap(PERMITTED_ATTRIBS[params[:class_name]]).include?(params[:attrib])
    render(json: {error: ["Unpermitted attribute"]}, status: :forbidden)
  end
end
