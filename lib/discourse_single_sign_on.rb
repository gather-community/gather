# frozen_string_literal: true

# Implements the Discourse single sign on protocol by providing
# the means to encode, decode, and sign the URLs and payloads required.
class DiscourseSingleSignOn
  class ParseError < RuntimeError; end

  ACCESSORS = %i[add_groups admin moderator avatar_force_update avatar_url bio card_background_url
                 email external_id groups locale locale_force_update name nonce profile_background_url
                 remove_groups require_activation return_sso_url suppress_welcome_message
                 title username website].freeze

  # Lists of accessors of numeric or boolean type. This helps with encoding them.
  FIXNUMS = [].freeze
  BOOLS = %i[admin avatar_force_update locale_force_update moderator
             require_activation suppress_welcome_message].freeze

  attr_accessor(*ACCESSORS)
  attr_accessor :secret, :return_url

  def initialize(payload:, signature:, secret:, return_url: nil)
    raise ParseError, "Payload and signature are required" if payload.blank? || signature.blank?

    self.secret = secret
    self.return_url = return_url

    decoded = Base64.decode64(payload)
    decoded_hash = Rack::Utils.parse_query(decoded)

    if sign(payload) != signature
      if payload =~ %r{[^a-zA-Z0-9=\r\n/+]}m
        diags = "\n\npayload: #{payload}"
        raise ParseError, "Invalid chars in SSO field.#{diags}"
      else
        diags = "\n\npayload: #{payload}\n\nsig: #{signature}\n\nexpected sig: #{sign(payload)}"
        raise ParseError, "Bad signature for payload.#{diags}"
      end
    end

    ACCESSORS.each do |k|
      next if public_send(k)
      val = decoded_hash[k.to_s]
      val = val.to_i if FIXNUMS.include?(k)
      if BOOLS.include?(k)
        val = %w[true false].include?(val) ? val == "true" : nil
      end
      public_send("#{k}=", val)
    end

    # Override the given return URL if one is provided in the payload.
    self.return_url = return_sso_url if return_sso_url.present?

    decoded_hash.each do |k, v|
      if (field = k[/^custom\.(.+)$/, 1])
        custom_fields[field] = v
      end
    end
  end

  def custom_fields
    @custom_fields ||= {}
  end

  def to_url
    "#{return_url}#{return_url.include?('?') ? '&' : '?'}#{return_payload}"
  end

  private

  def sign(payload)
    OpenSSL::HMAC.hexdigest("sha256", secret, payload)
  end

  def return_payload
    payload = Base64.strict_encode64(unsigned_return_payload)
    "sso=#{CGI.escape(payload)}&sig=#{sign(payload)}"
  end

  def unsigned_return_payload
    payload = {}

    ACCESSORS.each do |k|
      next if (val = public_send(k)).nil?
      payload[k] = val
    end

    @custom_fields&.each do |k, v|
      payload["custom.#{k}"] = v.to_s
    end

    Rack::Utils.build_query(payload)
  end
end
