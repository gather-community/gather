# frozen_string_literal: true

module Deactivatable
  extend ActiveSupport::Concern

  included do
    scope :active, -> { where(deactivated_at: nil) }
    scope :inactive, -> { where.not(deactivated_at: nil) }
    scope :active_or_selected, ->(ids) { where(deactivated_at: nil).or(where(id: Array.wrap(ids))) }
    scope :deactivated_last, -> { order(arel_table[:deactivated_at].not_eq(nil)) }

    def self.after_deactivate(&block)
      class_variable_set("@@after_deactivate_callbacks", after_deactivate_callbacks << block)
    end

    def self.after_deactivate_callbacks
      return [] unless class_variable_defined?("@@after_deactivate_callbacks")

      class_variable_get("@@after_deactivate_callbacks")
    end
  end

  def activate
    update!(deactivated_at: nil)
  end

  def deactivate(options = {})
    update!(deactivated_at: Time.current)
    self.class.after_deactivate_callbacks.each { |c| instance_eval(&c) } unless options[:skip_callback]
  end

  def active?
    deactivated_at.nil?
  end

  def inactive?
    !active?
  end
end
