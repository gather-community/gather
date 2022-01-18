class SetShowLegacyCalendarExportLinksForExistingUsers < ActiveRecord::Migration[6.0]
  def up
    ActsAsTenant.without_tenant do
      execute("UPDATE users SET settings = settings ||
        jsonb_build_object('show_legacy_calendar_export_links', true)")
    end
  end
end
