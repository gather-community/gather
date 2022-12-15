# frozen_string_literal: true

module GDrive
  # Stores/loads/deletes token information using the GDrive::Config and GDrive::Token models.
  # Conforms to the GDrive API TokenStore contract.
  class TokenStore
    attr_accessor :config

    def initialize(config:)
      self.config = config
    end

    def load(google_user_id)
      config.tokens.find_by(google_user_id: google_user_id)&.data
    end

    # We never create Config objects via this method, only update.
    # Creation is done manually. But we still need the store method for token refreshes, which happen
    # under the hood.
    def store(google_user_id, token_data)
      config.tokens.find_or_initialize_by(google_user_id: google_user_id).update!(data: token_data)
    end

    def delete(google_user_id)
      config.tokens.find_by(google_user_id: google_user_id)&.destroy
    end
  end
end
