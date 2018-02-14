# Models a set of parameters and parameter values that scope an index view.
module Lens
  class Lens
    attr_accessor :fields, :params, :values, :context

    LENS_VERSION = 2

    # Gets the last explicit path for the given controller and action.
    # `context` - The calling view.
    def self.path_for(context:, controller:, action:)
      context.session["lenses"].try(:[], controller).try(:[], action).try(:[], "_path")
    end

    # `context` - The calling controller.
    # `fields` - The names of the fields that make up the lens, e.g. [:community, :search].
    #    Can be a hash or an array. If a hash, the values are hashes of options.
    # `params` - The Rails params hash.
    def initialize(context:, fields:, params:)
      self.context = context
      self.fields ||= []
      add_fields(fields)
      fields = self.fields

      store = (context.session[:lenses] ||= {})

      # Expire old lens if version has been upgraded.
      if (store["version"] || 1) < LENS_VERSION
        store = context.session[:lenses] = {"version" => LENS_VERSION}
      end

      store[context.controller_name] ||= {}
      self.values = (store[context.controller_name][context.action_name] ||= {})

      # Copy lens params from the params hash.
      fields.each do |f|
        self[f.name] = params[f.name] if params.has_key?(f.name)
      end

      # Save the path if params explictly given, but clear path if all params are blank.
      if (params.keys & fields.map(&:to_s)).present?
        if params.slice(*fields.map(&:name)).values.all?(&:blank?)
          delete(:_path)
        else
          self[:_path] = context.request.fullpath.gsub(/(&\w+=\z|\w+=&)/, "")
        end
      end
    end

    def bar(options = {})
      Bar.new(context: context, lens: self, options: options)
    end

    def blank?
      fields.none? { |f| self[f].present? }
    end

    def optional_fields_blank?
      optional_fields.none? { |f| self[f].present? }
    end

    def all_required?
      fields.all?(&:required?)
    end

    def optional_fields
      fields.reject(&:required?)
    end

    def remove_field(name)
      fields.reject! { |f| f.name == name }
    end

    def query_string_to_clear
      optional_fields.map { |f| "#{f.to_s}=" }.join("&")
    end

    def [](key)
      # Convert to string because the session hash uses strings.
      values[key.to_s]
    end

    def []=(key, value)
      values[key.to_s] = value
    end

    def delete(key)
      self.values.delete(key.to_s)
    end

    private

    def add_fields(fields)
      if fields.is_a?(Hash)
        fields.each do |k, v|
          add_field(k, v)
        end
      elsif fields.is_a?(Array)
        fields.each do |f|
          if f.is_a?(Symbol)
            add_field(f, {})
          elsif f.is_a?(Hash)
            add_fields(f)
          else
            raise "Invalid field value #{f.inspect}"
          end
        end
      else
        raise "Invalid field value #{f.inspect}"
      end
    end

    def add_field(name, options)
      fields << Field.new(name: name.to_sym, options: options)
    end
  end
end
