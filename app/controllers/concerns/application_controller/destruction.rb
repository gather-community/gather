module Concerns::ApplicationController::Destruction
  extend ActiveSupport::Concern

  def destroy
    simple_action(:destroy)
  end

  def activate
    simple_action(:activate)
  end

  def deactivate
    simple_action(:deactivate)
  end

  private

  def simple_action(action)
    object = klass.find(params[:id])
    authorize(object)
    object.send(action)
    flash[:success] = I18n.t("successes.#{object.model_name.i18n_key}.#{action}")
    redirect_to(send("#{object.model_name.route_key}_path"))
  end
end
