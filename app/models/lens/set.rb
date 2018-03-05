# Models a set of parameters and parameter values that scope an index view.
module Lens
  class Set
    attr_accessor :lenses, :route_params, :context, :visible
    alias_method :visible?, :visible

    LENS_VERSION = 4

    # Gets the last explicit path for the given controller and action.
    # `context` - The calling view.
    def self.path_for(context:, controller:, action:)
      context.session["lenses"].try(:[], controller).try(:[], action).try(:[], "_path")
    end

    # `context` - The calling controller.
    # `lens_names` - The names of the lenses that make up the set, e.g. [:community, :search].
    #    Can be a hash or an array. If a hash, the values are hashes of options.
    # `route_params` - The Rails params hash.
    def initialize(context:, lens_names:, route_params:)
      # permit! is ok because params are never used in Lens to do mass assignments.
      self.route_params = route_params.dup.permit!
      self.context = context
      self.lenses ||= []
      self.visible = true
      context.session.delete(:lenses) if route_params[:clearlenses]
      expire_store_on_version_upgrade
      build_lenses(lens_names)
      save_or_clear_path
    end

    def bar(options = {})
      Bar.new(context: context, set: self, options: options)
    end

    def blank?
      lenses.all?(&:blank?)
    end

    def hide!
      self.visible = false
    end

    def optional_lenses
      lenses.reject(&:required?)
    end

    def optional_lenses_active?
      optional_lenses.any?(&:active?)
    end

    def [](param_name)
      lenses_by_param_name[param_name.to_sym]
    end

    def remove_lens(full_name)
      lenses.reject! { |l| l.full_name == full_name }
    end

    def path_to_clear
      context.request.path << "?" << query_string_to_clear
    end

    def cache_key
      lenses.map { |l| [l.param_name, l.value] }.to_h.to_query
    end

    def query_string_to_clear
      optional_lenses.map { |l| [l.param_name, ""] }.to_h.to_query
    end

    # If there are optional filters set, return some text and a link indicating they can clear them.
    def no_result_clear_filter_link
      if optional_lenses_active?
        link = view.link_to(I18n.t("common.clearing_the_filter"), path_to_clear)
        view.t("common.no_result_clear_filter_link_html", link: link)
      else
        ""
      end
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
      klass = (name.to_s.classify << "Lens").constantize
      lenses << klass.new(
        options: options,
        context: context,
        route_params: route_params,
        stores: stores
      )
    end

    def root_store
      @root_store ||= (context.session[:lenses] ||= {})
    end

    def stores
      @stores ||= {global: global_store, action: action_store}
    end

    # Returns (and inits if necessary) the portion of the root_store for the
    # current controller and action.
    def action_store
      return @action_store if defined?(@action_store)
      root_store[context.controller_name] ||= {}
      @action_store = (root_store[context.controller_name][context.action_name] ||= {})
    end

    # Returns (and inits if necessary) the portion of the root_store for global lenses.
    def global_store
      @global_store = (root_store["_global"] ||= {})
    end

    def expire_store_on_version_upgrade
      if (root_store["version"] || 1) < LENS_VERSION
        @root_store = context.session[:lenses] = {"version" => LENS_VERSION}
      end
    end

    # Save the path if any non-global route_params explictly given,
    # but clear path if all route_params are blank. This is used for rewriting nav links.
    # We ignore non-global route_params because including such params in rewritten links would
    # mess with the global nature of the lens.
    def save_or_clear_path
      non_global_param_names = lenses.reject(&:global?).map(&:param_name)
      if (route_params.keys.map(&:to_sym) & non_global_param_names).present?
        non_global_params = route_params.slice(*non_global_param_names).reject { |_, v| v.blank? }
        if non_global_params.values.all?(&:blank?)
          action_store.delete("_path")
        else
          action_store["_path"] = "#{context.request.path}?#{non_global_params.to_query}"
        end
      end
    end

    def lenses_by_param_name
      @lenses_by_param_name ||= lenses.index_by(&:param_name)
    end

    def view
      context.view_context
    end
  end
end
