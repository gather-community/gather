module SMTPFix
  def initialize(address, port = nil)
    super
    @starttls = false
  end
end

Net::SMTP.prepend(SMTPFix)
