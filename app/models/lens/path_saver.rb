# frozen_string_literal: true

module Lens
  # Remembers paths for url rewriting.
  class PathSaver
    attr_accessor :storage

    KEY = "_path"
    CHAR_LIMIT = 128

    def initialize(storage:)
      self.storage = storage
    end

    # Save the path if any non-global route params explictly given,
    # but clear path if all route_params are blank.
    # We ignore global route_params because including such params in rewritten links would
    # mess with the global nature of the lens.
    def write(lenses:, path:, params:)
      non_global_param_names = lenses.reject(&:global?).map(&:param_name)
      return if (params.keys.map(&:to_sym) & non_global_param_names).empty?

      # We can call permit! b/c these are not bound for mass assignment.
      non_global_params = params.slice(*non_global_param_names).reject { |_, v| v.blank? }.permit!
      if non_global_params.values.all?(&:blank?)
        storage.action_store.delete(KEY)
      else
        # Limit the path length to avoid overlowing the cookie. 128 should be plenty for legit paths.
        storage.action_store[KEY] = "#{path}?#{non_global_params.to_query}"[0..CHAR_LIMIT]
      end
    end

    def read
      storage.action_store[KEY]
    end
  end
end
