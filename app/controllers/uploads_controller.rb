# frozen_string_literal: true

class UploadsController < ApplicationController
  # Accepts uploaded files and stores them as Blobs, returning the signed_id for use in forms.
  def create
    authorize(Upload.new)
    blob = ActiveStorage::Blob.create_after_upload!(io: params[:file].open,
                                                    filename: params[:file].original_filename)
    render(json: {blob_id: blob.signed_id}, status: :created)
  end
end
