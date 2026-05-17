# frozen_string_literal: true

# ActiveStorage::AnalyzeJob runs in background without a tenant context.
# After analysis, it calls touch_attachments, which preloads the polymorphic
# record association on attachments (User, Calendar, etc. — all tenant-scoped),
# causing ActsAsTenant to raise NoTenantSet. Running without_tenant allows
# the queries to proceed unscoped, which is safe since blob analysis is
# purely about reading file content and saving metadata.
module ActiveStorageAnalyzeJobTenantPatch
  def perform(blob)
    ActsAsTenant.without_tenant { super }
  end
end

Rails.application.config.to_prepare do
  unless ActiveStorage::AnalyzeJob <= ActiveStorageAnalyzeJobTenantPatch
    ActiveStorage::AnalyzeJob.prepend(ActiveStorageAnalyzeJobTenantPatch)
  end
end
