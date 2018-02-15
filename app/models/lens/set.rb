# Models a set of parameters and parameter values that scope an index view.
module Lens
  class Set
    attr_accessor :lenses, :params, :values, :context

    LENS_VERSION = 2

    # Gets the last explicit path for the given controller and action.
    # `context` - The calling view.
    def self.path_for(context:, controller:, action:)
      context.session["lenses"].try(:[], controller).try(:[], action).try(:[], "_path")
    end

    # `context` - The calling controller.
    # `lens_names` - The names of the lenses that make up the set, e.g. [:community, :search].
    #    Can be a hash or an array. If a hash, the values are hashes of options.
    # `params` - The Rails params hash.
    def initialize(context:, lens_names:, params:)
      self.context = context
      self.lenses ||= []
      add_lenses(lens_names)
      lenses = self.lenses

      store = (context.session[:lenses] ||= {})

      # Expire old set if version has been upgraded.
      if (store["version"] || 1) < LENS_VERSION
        store = context.session[:lenses] = {"version" => LENS_VERSION}
      end

      store[context.controller_name] ||= {}
      self.values = (store[context.controller_name][context.action_name] ||= {})

      # Copy lens params from the params hash.
      lenses.each do |l|
        self[l.name] = params[l.name] if params.has_key?(l.name)
      end

      # Save the path if params explictly given, but clear path if all params are blank.
      if (params.keys & lenses.map(&:to_s)).present?
        if params.slice(*lenses.map(&:name)).values.all?(&:blank?)
          delete(:_path)
        else
          self[:_path] = context.request.fullpath.gsub(/(&\w+=\z|\w+=&)/, "")
        end
      end
    end

    def bar(options = {})
      Bar.new(context: context, set: self, options: options)
    end

    def blank?
      lenses.none? { |l| self[l].present? }
    end

    def optional_lenses_blank?
      optional_lenses.none? { |l| self[l].present? }
    end

    def all_required?
      lenses.all?(&:required?)
    end

    def optional_lenses
      lenses.reject(&:required?)
    end

    def remove_lens(name)
      lenses.reject! { |l| l.name == name }
    end

    def query_string_to_clear
      optional_lenses.map { |l| "#{l.to_s}=" }.join("&")
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

    def add_lenses(names)
      if names.is_a?(Hash)
        names.each do |k, v|
          add_lens(k, v)
        end
      elsif names.is_a?(Array)
        names.each do |l|
          if l.is_a?(Symbol)
            add_lens(l, {})
          elsif l.is_a?(Hash)
            add_lenses(l)
          else
            raise "Invalid lens value #{l.inspect}"
          end
        end
      else
        raise "Invalid lens value #{l.inspect}"
      end
    end

    def add_lens(name, options)
      klass = class_for_lens_name(name)
      lenses << klass.new(name: name.to_sym, options: options, context: context, set: self)
    end

    def class_for_lens_name(name)
      words = name.to_s.split("_").map(&:capitalize) << "Lens"
      words.insert(1, "::") if words.size > 2
      words.join.constantize
    end
  end
end
