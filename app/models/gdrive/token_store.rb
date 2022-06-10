# frozen_string_literal: true

module GDrive
  # Stores/loads/deletes token information using the GDrive::Config model.
  # Conforms to the GDrive API TokenStore contract.
  class TokenStore
    def load(community_id)
      Config.find_by(community_id: community_id)&.token
    end

    # We never create Config objects via this method, only update.
    # Creation is done manually when a Google account is first linked for the community.
    # We do it manually so we can also store the google ID and thus not violate the null
    # constraint on that column. But we still need the store method for token refreshes, which happen
    # under the hood.
    def store(community_id, token)
      Config.find_by!(community_id: community_id).update!(token: token)
    end

    def delete(community_id)
      Config.find_by(community_id: community_id)&.destroy
    end
  end
end
