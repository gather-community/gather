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

  protected

  def after_destroy(object)
    flash[:success] = I18n.t("deactivatable.#{object.model_name.i18n_key}.success.destroy")
  end

  def after_activate(object)
    flash[:success] = I18n.t("deactivatable.#{object.model_name.i18n_key}.success.activate")
  end

  def after_deactivate(object)
    flash[:success] = I18n.t("deactivatable.#{object.model_name.i18n_key}.success.deactivate")
  end

  private

  def simple_action(action)
    object = klass.find(params[:id])
    authorize(object)
    begin
      object.send(action)
      send("after_#{action}", object)
      redirect_appropriately(action, object)
    rescue ActiveRecord::RecordInvalid
      message = object.errors.full_messages.join("; ")
      flash[:error] = I18n.t("deactivatable.#{object.model_name.i18n_key}.error.#{action}", message: message)
      redirect_to(send("edit_#{object.model_name.singular_route_key}_path", object))
    end
  end

  def redirect_appropriately(action, object)
    redirect_to(action == :destroy || !respond_to?(:show) ? collection_path(object) : member_path(object))
  end

  def collection_path(object)
    send("#{object.model_name.route_key}_path")
  end

  def member_path(object)
    send("#{object.model_name.singular_route_key}_path", object)
  end
end
