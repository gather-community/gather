# frozen_string_literal: true

module Lens
  # A lens that appears as a select tag.
  class SelectLens < ::Lens::Lens
    def self.i18n_key(key = nil)
      class_var_get_or_set(:i18n_key, key)
    end

    def self.select_prompt(prompt = nil)
      unless prompt.nil?
        define_method(:"#{prompt}?") do
          value.nil?
        end
      end
      class_var_get_or_set(:select_prompt, prompt)
    end

    def self.possible_options(options = nil)
      options&.each do |option|
        define_method(:"#{option}?") do
          value == option.to_s
        end
      end
      class_var_get_or_set(:possible_options, options)
    end

    def render
      select_tag
    end

    protected

    delegate :i18n_key, :select_prompt, :possible_options, to: :klass

    def klass
      self.class
    end

    def select_tag
      h.select_tag(param_name, option_tags,
        prompt: translated_select_prompt,
        class: "form-control",
        id: select_tag_id,
        onchange: onchange,
        "data-param-name": param_name)
    end

    def select_input_name
      param_name
    end

    def select_tag_id
      nil
    end

    def onchange
      "this.form.submit();"
    end

    def translated_select_prompt
      select_prompt.is_a?(Symbol) ? translate_option(select_prompt) : select_prompt
    end

    def option_tags
      tags_for_options(possible_options)
    end

    def tags_for_options(options)
      h.options_for_select(options.map { |o| [translate_option(o), o] }, value)
    end

    def translate_option(option)
      I18n.t("#{i18n_key}.#{option}")
    end
  end
end
