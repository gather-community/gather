# frozen_string_literal: true

# == Schema Information
#
# Table name: gdrive_migration_logs
#
#  id           :bigint           not null, primary key
#  cluster_id   :bigint           not null
#  created_at   :datetime         not null
#  data         :jsonb
#  level        :string           not null
#  message      :text             not null
#  operation_id :bigint           not null
#
module GDrive
  module Migration
    class Log < ApplicationRecord
      acts_as_tenant :cluster

      belongs_to :operation, inverse_of: :logs
    end
  end
end
