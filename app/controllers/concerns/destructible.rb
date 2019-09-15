# frozen_string_literal: true

module Destructible
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
    begin
      object.send(action)
      flash[:success] = I18n.t("deactivatable.#{object.model_name.i18n_key}.success.#{action}")
      redirect_to(send("#{object.model_name.route_key}_path"))
    rescue ActiveRecord::RecordInvalid
      message = object.errors.full_messages.join("; ")
      flash[:error] = I18n.t("deactivatable.#{object.model_name.i18n_key}.error.#{action}", message: message)
      redirect_to(send("edit_#{object.model_name.singular_route_key}_path", object))
    end
  end
end
