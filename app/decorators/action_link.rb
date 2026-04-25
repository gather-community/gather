# frozen_string_literal: true

class ActionLink < ApplicationDecorator
  attr_accessor :object, :action, :icon, :method, :path, :confirm, :confirm_args,
    :btn_class, :permitted, :label_symbol, :extra_data, :extra_html

  def initialize(object, action, icon:, path:, btn_class: :default, label_symbol: action,
    method: :get, permitted: nil, confirm: false, data: {}, html: {})
    self.object = object
    self.action = action
    self.icon = icon
    self.path = path
    self.method = method
    self.confirm_args = confirm.is_a?(Hash) ? confirm : {}
    self.confirm = confirm != false
    self.btn_class = btn_class
    self.label_symbol = label_symbol
    self.permitted = permitted
    self.extra_data = data
    self.extra_html = html
  end

  def render
    return @rendered if defined?(@rendered)
    @rendered =
      if permitted || permitted.nil? && h.policy(object).send("#{action}?")
        params = {title: label, method: method, class: "btn btn-#{btn_class}"}
        params.merge!(extra_html)
        data_hash = extra_data.dup
        data_hash[:confirm] = confirm_msg if confirm_msg
        params[:data] = data_hash unless data_hash.empty?
        h.link_to(icon_tag << label_tag, path, params)
      end
  end

  private

  def icon_tag
    h.icon_tag(icon)
  end

  def label_tag
    h.content_tag(:span, label, class: "action-label")
  end

  def label
    t(:"action_labels.#{i18n_key}.#{label_symbol}", default: :"action_labels.common.#{label_symbol}")
  end

  def i18n_key
    object.model_name.i18n_key
  end

  def confirm_msg
    return @confirm_msg if defined?(@confirm_msg)
    return @confirm_msg = nil unless confirm
    @confirm_msg = I18n.t("confirmations.#{object.model_name.i18n_key}.#{action}", **confirm_args)
  end
end
