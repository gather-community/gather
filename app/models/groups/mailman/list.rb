# frozen_string_literal: true

module Groups
  module Mailman
    # Models a Mailman list.
    class List < ApplicationRecord
      acts_as_tenant :cluster

      belongs_to :domain
      belongs_to :group

      normalize_attributes :name

      validate :check_outside_addresses

      before_save :clean_outside_addresses

      private

      def check_outside_addresses
        %i[outside_members outside_senders].each do |attrib|
          next if self[attrib].blank?
          self[attrib].split("\n").each_with_index do |line, number|
            next if line.strip.empty?
            address = Mail::Address.new(line)
            raise Mail::Field::FieldError unless address.address.match?(::User::EMAIL_REGEXP)
          rescue Mail::UnknownEncodingType, Mail::Field::FieldError
            errors.add(attrib, "Error on line #{number + 1} (#{line})")
            break
          end
        end
      end

      def clean_outside_addresses
        %i[outside_members outside_senders].each do |attrib|
          next if self[attrib].blank?
          cleaned = self[attrib].split("\n").map { |l| Mail::Address.new(l).to_s unless l.strip.empty? }
          send("#{attrib}=", cleaned.compact.join("\n"))
        end
      end
    end
  end
end
