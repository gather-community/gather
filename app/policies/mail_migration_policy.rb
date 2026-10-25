# frozen_string_literal: true

# Headless policy for the mail domain migration page (authorized as the symbol :mail_migration).
class MailMigrationPolicy < ApplicationPolicy
  def index?
    active_super_admin?
  end
end
