# frozen_string_literal: true

module GDrive
  def self.table_name_prefix
    "gdrive_"
  end

  FOLDER_MIME_TYPE = "application/vnd.google-apps.folder"

  # Escapes a value for use inside single quotes in a Drive API query (the `q` parameter).
  def self.escape_query_value(value)
    value.to_s.gsub("\\", "\\\\\\\\").gsub("'", "\\\\'")
  end
end
