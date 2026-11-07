# frozen_string_literal: true

module Nav
  # Base class for the item lists Nav::Builder renders. Subclasses return unfiltered item hashes
  # (see Nav::Builder for their keys); the builder handles permissions and the active item.
  class Menu
    def initialize(builder)
      @builder = builder
    end

    def main_items
      []
    end

    def sub_items(_main_item)
      []
    end

    def sub_sub_items
      []
    end

    def personal_items
      []
    end

    protected

    attr_reader :builder

    delegate :h, :context, :current_period, :multi_community?, to: :builder

    def user
      h.current_user
    end

    def community
      h.current_community
    end

    def sign_out_item
      {
        name: :sign_out,
        parents: [:personal],
        path: h.destroy_user_session_path,
        permitted: true,
        icon: "sign-out",
        method: :delete
      }
    end
  end
end
