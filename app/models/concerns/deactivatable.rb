# frozen_string_literal: true

module Deactivatable
  extend ActiveSupport::Concern

  included do
    scope :active, -> { where(deactivated_at: nil) }
    scope :active_or_selected, ->(ids) { where(deactivated_at: nil).or(where(id: Array.wrap(ids))) }
    scope :deactivated_last, -> { order(arel_table[:deactivated_at].not_eq(nil)) }

    def self.after_deactivate(&block)
      callbacks = if class_variable_defined?("@@after_deactivate_callbacks")
                    class_variable_get("@@after_deactivate_callbacks")
                  else
                    []
                  end
      class_variable_set("@@after_deactivate_callbacks", callbacks << block)
    end
  end

  def activate
    update!(deactivated_at: nil)
  end

  def deactivate(options = {})
    update!(deactivated_at: Time.current)
    callbacks = self.class.class_variable_get("@@after_deactivate_callbacks") || []
    callbacks.each { |c| instance_eval(&c) } unless options[:skip_callback]
  end

  def active?
    deactivated_at.nil?
  end

  def inactive?
    !active?
  end
end
