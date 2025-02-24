# frozen_string_literal: true

# Generates unique tokens by looping until there are no matches in the same namespace.
class UniqueTokenGenerator
  include Singleton

  def self.generate(klass, attrib, **)
    instance.generate(klass, attrib, **)
  end

  def generate(klass, attrib, type: :devise)
    loop do
      token = case type
              when :devise then Devise.friendly_token
              when :hex32 then SecureRandom.hex(32)
              end
      break token unless klass.find_by(attrib => token)
    end
  end
end
