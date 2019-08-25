# frozen_string_literal: true

module People
  # Returns good, random passwords.
  class PasswordGenerator
    include Singleton

    def generate
      Devise.friendly_token[0, 16]
    end
  end
end
