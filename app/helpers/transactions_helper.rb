module TransactionsHelper
  def transaction_code_options
    Transaction::MANUALLY_ADDABLE_TYPES.map{ |t| [I18n.t("transaction_codes.#{t.code}"), t.code] }
  end
end
