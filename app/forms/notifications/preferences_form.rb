# frozen_string_literal: true

module Notifications
  # Edits a user's notification preferences. Has one boolean field per configurable kind and channel,
  # named like `meal_reminder_email`, so that adding a channel later just adds fields.
  class PreferencesForm
    include ActiveModel::Conversion
    include ActiveModel::Validations

    attr_reader :user

    def self.model_name
      ActiveModel::Name.new(self, nil, "Notifications::Preferences")
    end

    def self.field_name(kind, channel)
      :"#{kind.key}_#{channel}"
    end

    def self.field_names
      Catalog.configurable.flat_map do |kind|
        Catalog::CHANNELS.map { |channel| field_name(kind, channel) }
      end
    end

    Catalog.configurable.each do |kind|
      Catalog::CHANNELS.each do |channel|
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

    # Kinds this user can see, configurable and required, grouped by section in section order.
    def kinds_by_section
      kinds = Catalog.listed.select { |k| k.visible_to?(user) }.group_by(&:section)
      Catalog::SECTIONS.filter_map { |section| [section, kinds[section]] if kinds[section] }.to_h
    end

    def update(params)
      params = params.permit(@policy.permitted_notification_pref_attributes)
      kinds_by_section.values.flatten.select(&:configurable?).each do |kind|
        Catalog::CHANNELS.each do |channel|
          field = self.class.field_name(kind, channel).to_s
          next unless params.key?(field)
          user.set_notification_pref(kind.key, params[field] == "1", channel: channel)
        end
      end
      user.save!
    end
  end
end
