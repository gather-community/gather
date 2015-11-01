module AccountsHelper
  def invoice_amount(invoice)
    invoice.nil? ? "N/A" : link_to(number_to_currency(invoice.total_due), invoice)
  end
end
