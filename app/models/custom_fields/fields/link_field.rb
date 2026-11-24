# frozen_string_literal: true

module CustomFields
  module Fields
    # A link to another page, shown among the fields on a form. It holds no value of its own.
    # Declared with the `url` to link to:
    #   {key: :single_sign_on, type: :link, url: "/admin/sso-secret"}
    # Its label and link text are looked up under `custom_fields.labels` and `custom_fields.link_texts`.
    class LinkField < Field
      # Specs can be written by admins (e.g. user custom fields), so only allow links that can't run script.
      URL_PATTERN = %r{\A(/(?!/)|https?://)}i

      attr_reader :url

      def initialize(key:, url:, **params)
        unless url.is_a?(String) && url.match?(URL_PATTERN)
          raise ArgumentError, "Invalid link URL '#{url}'. Must be a path or an http(s) URL."
        end
        @url = url
        super(key: key, **params)
      end

      def type
        :link
      end

      def stored?
        false
      end

      def normalize(_value)
        nil
      end
    end
  end
end
