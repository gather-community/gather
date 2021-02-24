# frozen_string_literal: true

# Helper methods for using console.
# rubocop:disable Rails/Output
class ConsoleHelper
  include Singleton

  # Sets current tenant
  def tenant(name_or_id, exact: false)
    if name_or_id.is_a?(Integer)
      ActsAsTenant.current_tenant = Cluster.find(name_or_id)
    else
      search = exact ? name_or_id : "%#{name_or_id}%"
      matches = Cluster.where("name ILIKE ?", search)
      if matches.count > 1
        puts("More than one match for #{name_or_id}. Use exact: true or a more specific search.")
        return
      elsif matches.empty?
        puts("No matches found for #{name_or_id}. (exact mode: #{exact ? 'on' : 'off'})")
        return
      end
      ActsAsTenant.current_tenant = matches.first
    end
  end

  # For debugging session storage.
  def verify_and_decrypt_session_cookie(cookie, secret_key_base = Rails.application.secret_key_base)
    config = Rails.application.config
    cookie = CGI.unescape(cookie)
    salt = config.action_dispatch.authenticated_encrypted_cookie_salt
    encrypted_cookie_cipher = config.action_dispatch.encrypted_cookie_cipher || "aes-256-gcm"
    serializer = ActionDispatch::Cookies::JsonSerializer
    key_generator = ActiveSupport::KeyGenerator.new(secret_key_base, iterations: 1000)
    key_len = ActiveSupport::MessageEncryptor.key_len(encrypted_cookie_cipher)
    secret = key_generator.generate_key(salt, key_len)
    encryptor = ActiveSupport::MessageEncryptor.new(secret, cipher: encrypted_cookie_cipher,
                                                            serializer: serializer)
    session_key = config.session_options[:key].freeze
    encryptor.decrypt_and_verify(cookie, purpose: "cookie.#{session_key}")
  end
end
# rubocop:enable Rails/Output

CH = ConsoleHelper.instance
