module ReimbursementRequestsHelper
  def payment_method_options
    ReimbursementRequest::PAYMENT_METHODS.map{ |m| [I18n.t("payment_methods.#{m}"), m] }
  end
end
