# frozen_string_literal: true

shared_context "gdrive" do
  before do
    stub_client_secret
  end

  # Google oauth API requests for a new access_token include the client secret which we don't want to leak.
  # It is stored on the Settings object. So after we have captured the request, we change the cassette
  # to have all x's as the client secret and add a call to this method in the spec.
  def stub_client_secret
    allow(Settings.gdrive.auth).to receive(:client_secret).and_return("xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx")
  end
end
