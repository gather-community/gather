# frozen_string_literal: true

module GDrive
  # Stores/loads/deletes token information using the GDrive::Config model.
  # Conforms to the GDrive API TokenStore contract.
  class TokenStore
    attr_accessor :klass

    def initialize(klass:)
      self.klass = klass
    end

    def load(community_id)
      klass.find_by(community_id: community_id)&.token
    end

    # We never create Config objects via this method, only update.
    # Creation is done manually. But we still need the store method for token refreshes, which happen
    # under the hood.
    def store(community_id, token)
      klass.find_by!(community_id: community_id).update!(token: token)
    end

    def delete(community_id)
      klass.find_by(community_id: community_id)&.destroy
    end
  end
end
