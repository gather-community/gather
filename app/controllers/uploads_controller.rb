class UploadsController < ApplicationController
  UPLOADABLES = {user: [:photo]}

  def create
    skip_authorization
    uploadable_attrs = UPLOADABLES[params[:model].to_sym]
    if uploadable_attrs.nil?
      return render plain: 'Invalid model', status: 403
    elsif !uploadable_attrs.include?(params[:attribute].to_sym)
      return render plain: 'Invalid attribute', status: 403
    else
      object = params[:model].camelize.constantize.new
      object.send("#{params[:attribute]}=", params[:file])
      object.send("#{params[:attribute]}_tmp_id=", params[:tmp_id])
      object.send(params[:attribute]).save_tmp
      render nothing: true
    end
  end
end
