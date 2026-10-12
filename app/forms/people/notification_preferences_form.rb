# frozen_string_literal: true

module People
  # Edits a user's notification preferences. Has one boolean field per configurable kind and channel,
  # named like `meal_reminder_email`, so that adding a channel later just adds fields.
  class NotificationPreferencesForm
    include ActiveModel::Conversion
    include ActiveModel::Validations

    attr_reader :user

    def self.model_name
      ActiveModel::Name.new(self, nil, "People::NotificationPreferences")
    end

    def self.field_name(kind, channel)
      :"#{kind.key}_#{channel}"
    end

    def self.field_names
      NotificationCatalog.configurable.flat_map do |kind|
        NotificationCatalog::CHANNELS.map { |channel| field_name(kind, channel) }
      end
    end

    NotificationCatalog.configurable.each do |kind|
      NotificationCatalog::CHANNELS.each do |channel|
        define_method(field_name(kind, channel)) { user.notification_enabled?(kind.key, channel: channel) }
      end
    end

    def initialize(user:, policy:)
      @user = user
      @policy = policy
    end

    def persisted?
      true
    end

    # Configurable kinds this user can see, grouped by section, in catalog order.
    def configurable_kinds_by_section
      NotificationCatalog.configurable.select { |k| k.visible_to?(user) }.group_by(&:section)
    end

    def required_kinds
      NotificationCatalog.required.select { |k| k.visible_to?(user) }
    end

    def update(params)
      params = params.permit(@policy.permitted_notification_pref_attributes)
      configurable_kinds_by_section.values.flatten.each do |kind|
        NotificationCatalog::CHANNELS.each do |channel|
          field = self.class.field_name(kind, channel).to_s
          next unless params.key?(field)
          user.set_notification_pref(kind.key, params[field] == "1", channel: channel)
        end
      end
      user.save!
    end
  end
end
