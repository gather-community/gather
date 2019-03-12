# frozen_string_literal: true

# Generates unique tokens by looping until there are no matches in the same namespace.
class UniqueTokenGenerator
  include Singleton

  def self.generate(*args)
    instance.generate(*args)
  end

  def generate(klass, attrib)
    loop do
      token = Devise.friendly_token
      break token unless klass.find_by(attrib => token)
    end
  end
end
