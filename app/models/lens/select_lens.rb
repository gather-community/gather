# frozen_string_literal: true

module Lens
  # A lens that appears as a select tag.
  class SelectLens < ::Lens::Lens
    delegate :empty?, to: :enabled_options

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

    # True if selection is not default.
    def clearable_and_active?
      return false if empty?
      clearable? && selection != default_option
    end

    def render
      return nil if empty?
      select_tag
    end

    def selection
      return nil if empty?
      @selection ||= possible_options.detect { |o| value_matches_option?(o) }
    end

    protected

    delegate :i18n_key, :possible_options, to: :klass

    def klass
      self.class
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

    def name_for_object_option(option)
      option.name
    end

    private

    def select_tag
      h.select_tag(select_input_name, option_tags,
                   class: css_classes,
                   onchange: onchange,
                   "data-param-name": param_name)
    end

    # Depends on enabled_options, which depends on possible_options. So if the lens doesn't
    # define possible_options, it can't use this method.
    def option_tags
      select_options = [default_option].concat(enabled_options - [default_option])
      pairs = select_options.map { |o| pair_for_option(o) }
      h.options_for_select(pairs, value_is_default_option? ? nil : value)
    end

    # Returns pair of strings for use in options_for_select.
    # If option is the default option and this is a clearable lens,
    # the value string (second in pair) will be nil.
    # That way, it's easy to construct a query string to clear (just all blank values).
    # All defaults should be first in the option list also, because when you set the value to nil
    # they will be selected.
    def pair_for_option(option)
      pair = [label_for_option(option), value_for_option(option)]
      pair[1] = nil if clearable? && option == default_option
      pair
    end

    def label_for_option(option)
      case option
      when Symbol
        translate_option(option)
      when String
        option
      when Array
        option[0]
      else
        name_for_object_option(option)
      end
    end

    def value_for_option(option)
      case option
      when Symbol
        option.to_s
      when String
        nil
      when Array
        option[1].to_s
      else
        option.id.to_s
      end
    end

    def translate_option(option)
      I18n.t("#{i18n_key}.#{option}")
    end

    def value_is_default_option?
      !default_option.nil? && value_matches_option?(default_option)
    end

    def value_matches_option?(option)
      option == default_option && value.nil? || value == value_for_option(option)
    end

    # Returns nil if select is empty.
    def default_option
      options[:default] || enabled_options.first
    end

    def enabled_options
      # Some lenses don't define possible_options.
      @enabled_options ||= (possible_options || []) - excluded_options
    end
  end
end
