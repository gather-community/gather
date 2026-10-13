# frozen_string_literal: true

module People
  # Lists every kind of email Gather sends, and where each one appears on the notification preferences page.
  #
  # Every mailer action must belong to exactly one kind. ApplicationMailer#mail raises for an action that
  # isn't listed here, and spec/models/people/notification_catalog_spec.rb checks all of them.
  #
  # There are three types of kind:
  # - configurable: listed on the page with a checkbox. Users can turn it off.
  # - required: listed on the page with a checked, disabled checkbox. Can't be turned off.
  # - internal: never goes to community members (applicants, Gather operators), so not on the page.
  #
  # Labels live in people.yml under people.notification_preferences.kinds.
  class NotificationCatalog
    TYPES = %i[configurable required internal].freeze
    SECTIONS = %i[account meals work billing community].freeze
    CHANNELS = %i[email].freeze

    Kind = Struct.new(:key, :type, :section, :mailer_actions, :audience, keyword_init: true) do
      def configurable?
        type == :configurable
      end

      def required?
        type == :required
      end

      # Whether this kind should be shown on the given user's preferences page.
      def visible_to?(user)
        return false if type == :internal
        audience.nil? || audience.call(user)
      end
    end

    # Mailer action names like "MealMailer#meal_reminder" aren't user-facing text.
    # rubocop:disable Gather/HardCodedString
    # In page order: kinds are shown in this order within each section.
    KINDS = [
      Kind.new(key: :account_access, type: :required, section: :account,
        mailer_actions: %w[AuthMailer#reset_password_instructions AuthMailer#cant_reset_password
          AuthMailer#confirmation_instructions AuthMailer#sign_in_invitation]),

      Kind.new(key: :meal_reminder, type: :configurable, section: :meals,
        mailer_actions: %w[MealMailer#meal_reminder]),
      Kind.new(key: :meal_role_reminder, type: :configurable, section: :meals,
        mailer_actions: %w[MealMailer#role_reminder]),
      Kind.new(key: :cook_menu_reminder, type: :configurable, section: :meals,
        mailer_actions: %w[MealMailer#cook_menu_reminder]),
      Kind.new(key: :meal_worker_change, type: :configurable, section: :meals,
        mailer_actions: %w[MealMailer#worker_change_notice]),
      Kind.new(key: :meal_message, type: :required, section: :meals,
        mailer_actions: %w[MealMailer#normal_message MealMailer#cancellation_message]),

      Kind.new(key: :job_reminder, type: :configurable, section: :work,
        mailer_actions: %w[WorkMailer#job_reminder]),
      Kind.new(key: :job_choosing_notice, type: :configurable, section: :work,
        mailer_actions: %w[WorkMailer#job_choosing_notice]),

      Kind.new(key: :statement_notice, type: :required, section: :billing,
        mailer_actions: %w[AccountMailer#statement_notice]),
      Kind.new(key: :statement_reminder, type: :configurable, section: :billing,
        mailer_actions: %w[AccountMailer#statement_reminder]),

      Kind.new(key: :gdrive_migration_request, type: :required, section: :community,
        mailer_actions: %w[GDrive::Migration::Mailer#migration_request],
        audience: ->(user) { FeatureFlag.lookup("gdrive").on?(user) }),
      Kind.new(key: :community_inactivity, type: :required, section: :community,
        mailer_actions: %w[Communities::InactivityMailer#warning],
        audience: ->(user) { user.global_role?(:admin) }),

      Kind.new(key: :community_signup, type: :internal,
        mailer_actions: %w[Communities::SignupMailer#notify_approvers Communities::SignupMailer#application_approved
          Communities::SignupMailer#application_denied Communities::SignupMailer#approval_created
          Communities::SignupMailer#approval_failed]),
      Kind.new(key: :operator, type: :internal,
        mailer_actions: %w[SystemMailer#inactivity_warning_summary TestMailer#test_mail])
    ].freeze
    # rubocop:enable Gather/HardCodedString

    BY_KEY = KINDS.index_by(&:key).freeze
    BY_MAILER_ACTION = KINDS.flat_map { |k| k.mailer_actions.map { |a| [a, k] } }.to_h.freeze

    def self.all
      KINDS
    end

    def self.find(key)
      BY_KEY[key.to_sym] || raise(ArgumentError, "Unknown notification kind: #{key}")
    end

    def self.for_mailer_action(mailer_class, action)
      BY_MAILER_ACTION["#{mailer_class.name}##{action}"]
    end

    def self.configurable
      KINDS.select(&:configurable?)
    end

    def self.required
      KINDS.select(&:required?)
    end

    # Kinds shown on the preferences page, configurable and required, in catalog order.
    def self.listed
      KINDS.select { |k| k.configurable? || k.required? }
    end
  end
end
