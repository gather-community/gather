# Models a set of parameters and parameter values that scope an index view.
module Lens
  class Set
    attr_accessor :lenses, :params, :context

    LENS_VERSION = 3

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
      build_lenses(lens_names)

      expire_store_on_version_upgrade

      # Copy lens params from the params hash, overriding params stored in the session.
      # Also set value on each lens.
      lenses.each do |l|
        substore[l.name.to_s] = params[l.param_name] if params.key?(l.param_name)
        l.value = substore[l.name.to_s]
      end

      save_or_clear_path(params)
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
      substore[key.to_s]
    end

    def []=(key, value)
      substore[key.to_s] = value
    end

    def delete(key)
      substore.delete(key.to_s)
    end

    private

    def build_lenses(names)
      if names.is_a?(Hash)
        names.each do |k, v|
          build_lens(k, v)
        end
      elsif names.is_a?(Array)
        names.each do |l|
          if l.is_a?(Symbol)
            build_lens(l, {})
          elsif l.is_a?(Hash)
            build_lenses(l)
          else
            raise "Invalid lens value #{l.inspect}"
          end
        end
      else
        raise "Invalid lens value #{l.inspect}"
      end
    end

    def build_lens(name, options)
      klass = class_for_lens_name(name)
      lenses << klass.new(
        name: name.to_sym,
        options: options,
        context: context
      )
    end

    def class_for_lens_name(name)
      words = name.to_s.split("_").map(&:capitalize) << "Lens"
      words.insert(1, "::") if words.size > 2
      words.join.constantize
    end

    def store
      @store ||= (context.session[:lenses] ||= {})
    end

    # Returns (and inits if necessary) the portion of the store for the
    # current controller and action.
    def substore
      return @substore if defined?(@substore)
      store[context.controller_name] ||= {}
      @substore = (store[context.controller_name][context.action_name] ||= {})
    end

    def expire_store_on_version_upgrade
      if (store["version"] || 1) < LENS_VERSION
        @store = context.session[:lenses] = {"version" => LENS_VERSION}
      end
    end

    # Save the path if params explictly given, but clear path if all params are blank.
    def save_or_clear_path(params)
      if (params.keys.map(&:to_sym) & lenses.map(&:param_name)).present?
        if params.slice(*lenses.map(&:param_name)).values.all?(&:blank?)
          delete(:_path)
        else
          self[:_path] = context.request.fullpath.gsub(/(&\w+=\z|\w+=&)/, "")
        end
      end
    end
  end
end
