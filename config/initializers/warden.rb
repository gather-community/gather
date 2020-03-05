# frozen_string_literal: true

Warden::Manager.before_logout do |user, _auth, _opts|
  include Wisper::Publisher
  broadcast(:user_signed_out, user)
end
