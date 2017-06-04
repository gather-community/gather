module Csv
  class HouseholdDecorator < ::HouseholdDecorator
    include Utils
    delegate_all
  end
end
