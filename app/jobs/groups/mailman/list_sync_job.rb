# frozen_string_literal: true

module Groups
  module Mailman
    # Synchronizes Gather lists to Mailman lists, including list memberships.
    class ListSyncJob < SyncJob
      attr_accessor :list

      def perform(list_id: nil, list_attribs: nil, destroyed: false)
        # If the list was destroyed, build a temporary one with the passed attributes.
        # Otherwise, load the persisted one.
        params = if destroyed
                   {klass: Mailman::List, attribs: list_attribs}
                 else
                   {klass: Mailman::List, id: list_id}
                 end
        with_object_in_cluster_context(**params) do |list|
          return api.delete_list(list) if destroyed
          api.create_domain(list.domain)
          create_or_update_list(list)
          api.configure_list(list)
          MembershipSyncJob.perform_later("Groups::Mailman::List", list.id)
        end
      end

      private

      def create_or_update_list(list)
        # Create will return nil if the list already exists.
        # If we get a non-nil return here, we know the create was successful.
        if (remote_id = api.create_list(list))
          list.update!(remote_id: remote_id)

          # `config` is an ephemeral attribute just used for passing things to the api adapter.
          # Since we just created this list, we send our full default set.
          list.config = List::DEFAULT_SETTINGS
        # Otherwise, the list must already exist, so we just load an abbreviated config that we enforce.
        else
          list.config = List::DEFAULT_SETTINGS.slice(*List::ENFORCED_SETTINGS)
        end
      end
    end
  end
end
