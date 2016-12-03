class UploadsController < ApplicationController
  UPLOADABLES = {user: [:photo]}

  def create
    authorize Upload
    if object = build_tmp_object
      object.send("#{params[:attribute]}=", params[:file])
      object.send(params[:attribute]).save_tmp
      render nothing: true
    end
  end

  def destroy
    authorize Upload
    object = build_tmp_object
    object.send(params[:attribute]).destroy
    render nothing: true
  end

  private

  def verify_params
    uploadable_attrs = UPLOADABLES[params[:model].to_sym]
    if uploadable_attrs.nil?
      render plain: 'Invalid model', status: 403
      false
    elsif !uploadable_attrs.include?(params[:attribute].to_sym)
      render plain: 'Invalid attribute', status: 403
      false
    else
      true
    end
  end

  def build_tmp_object
    if verify_params
      object = params[:model].camelize.constantize.new
      set_tmp_id_on(object)
    end
  end

  def set_tmp_id_on(object)
    object.send("#{params[:attribute]}_tmp_id=", params[:tmp_id])
    object
  end
end
