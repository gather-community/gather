module AccountsHelper
  def invoice_amount(invoice)
    invoice.nil? ? "N/A" : link_to(number_to_currency(invoice.total_due), invoice)
  end

  def currency_with_cr(amount)
    number_to_currency(amount.abs) << (amount < 0 ? " CR" : "")
  end
end
