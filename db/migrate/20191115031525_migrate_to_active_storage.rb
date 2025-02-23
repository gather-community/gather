# frozen_string_literal: true

require "fileutils"

class MigrateToActiveStorage < ActiveRecord::Migration[6.0]
  require "open-uri"

  def up
    ActiveRecord::Base.connection.raw_connection
      .prepare("active_storage_blob_statement", <<-SQL)
      INSERT INTO active_storage_blobs (
        "key", filename, content_type, metadata, byte_size, checksum, created_at
      ) VALUES ($1, $2, $3, '{}', $4, $5, $6) RETURNING id
    SQL

    ActiveRecord::Base.connection.raw_connection
      .prepare("active_storage_attachment_statement", <<-SQL)
      INSERT INTO active_storage_attachments (
        name, record_type, record_id, blob_id, created_at
      ) VALUES ($1, $2, $3, $4, $5)
    SQL

    Rails.application.eager_load!
    models = [User, Calendars::Calendar]

    ActsAsTenant.without_tenant do
      transaction do
        models.each do |model|
          attachments = model.column_names.map do |c|
            Regexp.last_match(1) if c =~ /(.+)_file_name$/
          end.compact

          if attachments.blank?
            raise "No attachments found on model #{model}. " \
                  "Make sure Paperclip still exists in code when this migration is run."
          elsif !model.first.send(attachments[0]).respond_to?(:path)
            raise "Model #{model} does not support Paperclip methods. " \
                  "Make sure Paperclip still exists in code when this migration is run."
          end

          model.find_each.each do |instance|
            attachments.each do |attachment|
              path = instance.send(attachment).path
              next if path.blank? || !File.exist?(path)

              result = ActiveRecord::Base.connection.raw_connection.exec_prepared(
                "active_storage_blob_statement", [
                  key(instance, attachment),
                  instance.send("#{attachment}_file_name"),
                  instance.send("#{attachment}_content_type"),
                  instance.send("#{attachment}_file_size"),
                  checksum(instance.send(attachment)),
                  instance.updated_at.iso8601
                ]
              )

              ActiveRecord::Base.connection.raw_connection.exec_prepared(
                "active_storage_attachment_statement", [
                  attachment,
                  model.name,
                  instance.id,
                  result.first["id"],
                  instance.updated_at.iso8601
                ]
              )
            end
          end
        end
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def key(_instance, _attachment)
    SecureRandom.uuid
    # Alternatively:
    # instance.send("#{attachment}_file_name")
  end

  def checksum(attachment)
    # local files stored on disk:
    Digest::MD5.base64digest(File.read(attachment.path))

    # remote files stored on another person's computer:
    # url = attachment.url
    # Digest::MD5.base64digest(Net::HTTP.get(URI(url)))
  end
end
