# frozen_string_literal: true

module People
  # Raised when adults have guardians defined.
  class AdultWithGuardianError < StandardError
  end
end
