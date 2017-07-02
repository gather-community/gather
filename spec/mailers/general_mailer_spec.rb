require "rails_helper"

describe "general mailer" do
  describe "mail to household with no emails" do
    let(:statement) { create(:statement, total_due: 9.99) }

    before do
      statement.household.users.each { |u| u.email = "" }
    end

    it "doesn't send" do
      expect(AccountMailer.statement_notice(statement).deliver_now).to be_nil
    end
  end
end
