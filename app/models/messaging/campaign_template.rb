# frozen_string_literal: true

module Messaging
  # The 10DLC campaign Gather registers for a community, rendered from config/messaging/campaign.yml.
  # See that file for why the wording lives there and not in the locale files.
  class CampaignTemplate
    PATH = Rails.root.join("config/messaging/campaign.yml")
    SAMPLE_MAX = 255
    MESSAGE_FLOW_MAX = 2048
    REPLY_MIN = 20

    # A rendered text field is too long or too short for Telnyx. This is our own wording, so it's a bug
    # to fix in campaign.yml, not something an admin can correct.
    class InvalidTemplateError < StandardError; end

    attr_reader :community

    def self.config
      @config ||= YAML.safe_load_file(PATH).freeze
    end

    def initialize(community)
      @community = community
    end

    def version
      config["version"]
    end

    def usecase
      config["usecase"]
    end

    def program_name
      # The community's name is the brand, so the program reads as theirs. The sample messages and
      # auto-replies all start with it.
      "#{community.name} texts" # rubocop:disable Gather/HardCodedString
    end

    def description
      render("description")
    end

    def message_flow
      render("message_flow", max: MESSAGE_FLOW_MAX)
    end

    def samples
      config["samples"].map { |sample| interpolate(sample, max: SAMPLE_MAX) }
    end

    def opt_in_message
      render("opt_in_message", max: SAMPLE_MAX, min: REPLY_MIN)
    end

    def help_message
      render("help_message", max: SAMPLE_MAX, min: REPLY_MIN)
    end

    def opt_out_message
      render("opt_out_message", max: SAMPLE_MAX, min: REPLY_MIN)
    end

    # The body for Telnyx's campaignBuilder endpoint, field names as the API spells them.
    def to_telnyx(brand_id:)
      samples.each_with_index.to_h { |sample, i| [:"sample#{i + 1}", sample] }.merge(
        brandId: brand_id,
        usecase: usecase,
        description: description,
        messageFlow: message_flow,
        optinMessage: opt_in_message,
        helpMessage: help_message,
        optoutMessage: opt_out_message,
        optinKeywords: config["opt_in_keywords"],
        optoutKeywords: config["opt_out_keywords"],
        helpKeywords: config["help_keywords"],
        embeddedLink: config["embedded_link"],
        embeddedPhone: config["embedded_phone"],
        numberPool: config["number_pool"],
        ageGated: config["age_gated"],
        directLending: config["direct_lending"],
        termsAndConditions: config["terms_and_conditions"],
        subscriberOptin: config["subscriber_opt_in"],
        subscriberOptout: config["subscriber_opt_out"],
        subscriberHelp: config["subscriber_help"],
        # There's no public Terms of Use page yet, so termsAndConditionsLink is left out.
        privacyPolicyLink: privacy_url,
        # Ties the campaign to the community, and stops a retried request registering a second campaign.
        referenceId: "gather-community-#{community.id}"
      )
    end

    private

    def config
      self.class.config
    end

    def render(key, max: nil, min: nil)
      interpolate(config.fetch(key), max: max, min: min)
    end

    def interpolate(text, max: nil, min: nil)
      result = format(text, **placeholders)
      if max && result.length > max
        raise InvalidTemplateError, "#{text[0, 30]}... renders to #{result.length} characters (max #{max})"
      end
      if min && result.length < min
        raise InvalidTemplateError, "#{text[0, 30]}... renders to #{result.length} characters (min #{min})"
      end
      result
    end

    def placeholders
      @placeholders ||= {
        community: community.name,
        program: program_name,
        opt_in_url: url("#{community.slug}.#{Settings.url.host}", url_helpers.notification_preferences_path),
        sample_url: url("#{community.slug}.#{Settings.url.host}", url_helpers.meals_path),
        screenshot_url: screenshot_url,
        privacy_url: privacy_url
      }
    end

    def screenshot_url
      Settings.messaging.opt_in_screenshot_url.presence ||
        raise(InvalidTemplateError, "Settings.messaging.opt_in_screenshot_url is not set")
    end

    def privacy_url
      url(Settings.url.host, "/about/privacy-policy")
    end

    # Matches ApplicationControllable::UrlHelpers, leaving out default ports.
    def url(host, path)
      port = Settings.url.port
      port = nil if [80, 443].include?(port.to_i)
      "#{Settings.url.protocol}://#{[host, port].compact.join(":")}#{path}"
    end

    def url_helpers
      Rails.application.routes.url_helpers
    end
  end
end
