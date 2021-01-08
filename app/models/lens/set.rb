# frozen_string_literal: true

module Lens
  # Models a set of parameters and parameter values that scope an index view.
  class Set
    attr_accessor :storage, :lenses, :route_params, :context, :visible
    alias visible? visible

    delegate :html, to: :bar

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
      self.storage = Storage.new(session: context.session, community_id: context.current_community.id,
                                 controller_path: context.controller_path, action_name: context.action_name)
      storage.reset if route_params[:clearlenses]
      build_lenses(lens_names)
      PathSaver.new(storage: storage).write(lenses: lenses, path: request_path, params: route_params)
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
      request_path << "?" << query_string_to_clear
    end

    def cache_key
      lenses.map { |l| [l.param_name, l.value] }.to_h.to_query
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
        storage: storage,
        set: self
      )

      # This hash may have been accessed and thus memoized by the lens just built,
      # but that could be a problem if it's not the last one, so force it to rebuild on the next access.
      @lenses_by_param_name = nil
    end

    def query_string_to_clear
      optional_lenses.map { |l| [l.param_name, ""] }.to_h.to_query
    end

    def lenses_by_param_name
      @lenses_by_param_name ||= lenses.index_by(&:param_name)
    end

    def bar
      @bar ||= Bar.new(context: context, set: self)
    end

    def view
      context.view_context
    end

    def request_path
      context.request.path
    end
  end
end
