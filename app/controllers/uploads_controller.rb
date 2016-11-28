class UploadsController < ApplicationController
  UPLOADABLES = {user: [:photo]}

  def create
    skip_authorization
    if object = build_object
      object.send("#{params[:attribute]}=", params[:file])
      object.send(params[:attribute]).save_tmp
      render nothing: true
    end
  end

  def destroy
    skip_authorization
    params[:tmp_id] = params[:id]
    if object = build_object
      object.send(params[:attribute]).destroy
      render nothing: true
    end
  end

  private

  def build_object
    uploadable_attrs = UPLOADABLES[params[:model].to_sym]
    if uploadable_attrs.nil?
      render plain: 'Invalid model', status: 403
      return nil
    elsif !uploadable_attrs.include?(params[:attribute].to_sym)
      render plain: 'Invalid attribute', status: 403
      return nil
    else
      params[:model].camelize.constantize.new.tap do |object|
        object.send("#{params[:attribute]}_tmp_id=", params[:tmp_id])
      end
    end
  end
end
