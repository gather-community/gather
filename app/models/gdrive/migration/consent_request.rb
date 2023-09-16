# frozen_string_literal: true

module GDrive
  module Migration
    class ConsentRequest < ApplicationRecord
      acts_as_tenant :cluster

      belongs_to :operation, class_name: "GDrive::Migration::Operation", inverse_of: :consent_requests
    end
  end
end
