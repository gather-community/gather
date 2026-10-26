# frozen_string_literal: true

# Base controller for operator (super admin) pages. These live on the apex domain and span all
# clusters; on the apex domain, tenant scoping is off, so queries cover every cluster.
class AdminController < ApplicationController
  protected

  def apex_domain_only
    true
  end
end
