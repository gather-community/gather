# frozen_string_literal: true

module Lens
  # A lens that appears as a select tag.
  class SelectLens < ::Lens::Lens
    def self.i18n_key(key = nil)
      class_var_get_or_set(:i18n_key, key)
    end

    def self.possible_options(possible_options = nil)
      possible_options&.each do |option|
        define_method(:"#{option}?") do
          value == option.to_s
        end
      end
      class_var_get_or_set(:possible_options, possible_options)
    end

    def active?
      value.present? && value != default_option.to_s
    end

    def render
      select_tag
    end

    protected

    delegate :i18n_key, :possible_options, to: :klass

    def klass
      self.class
    end

    def select_tag
      h.select_tag(select_input_name, option_tags,
                   class: css_classes,
                   onchange: onchange,
                   "data-param-name": param_name)
    end

    def select_input_name
      param_name
    end

    def onchange
      "this.form.submit();"
    end

    # Can be overridden
    def excluded_options
      []
    end

    def option_tags
      tags_for_options([default_option].concat(enabled_options - [default_option]))
    end

    def tags_for_options(select_options)
      h.options_for_select(select_options.map { |o| [translate_option(o), o] }, value_or_nil_if_default)
    end

    def translate_option(option)
      I18n.t("#{i18n_key}.#{option}")
    end

    private

    def value_or_nil_if_default
      value == default_option.to_s ? nil : value
    end

    def default_option
      options[:default] || enabled_options.first
    end

    def enabled_options
      @enabled_options ||= possible_options - excluded_options
    end
  end
end
