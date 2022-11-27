# frozen_string_literal: true

module GDrive
  # Ingests selected files by starring them and noting any unowned files.
  class FileIngestionJob < ApplicationJob
    attr_accessor :batch, :wrapper, :error_count

    delegate :gdrive_config, to: :batch
    delegate :community_id, to: :gdrive_config

    MAX_ERRORS = 10

    def perform(cluster_id:, batch_id:)
      ActsAsTenant.with_tenant(Cluster.find(cluster_id)) do
        self.batch = FileIngestionBatch.find(batch_id)
        self.wrapper = Wrapper.new(community_id: community_id)
        self.error_count = 0
        batch.picked["docs"].each do |doc|
          ingest_file(doc["id"], pick_data: doc)
          return if error_count >= MAX_ERRORS
        end
        star_any_unstarred_files
      end
    end

    private

    def ingest_file(file_id, pick_data: {}, from_unstarred_list: false)
      # This request may fail if the selected object was a shortcut and the user hadn't already picked
      # the target file. So we should handle that gracefully.
      # It could also lead to a duplicate insertion in the UnownedFile table if the target file HAS already
      # been picked. So we need to handle that gracefully too.
      Rails.logger.info("[GDrive] Marking file #{file_id} as starred")
      begin
        file = wrapper.service.update_file(
          file_id,
          Google::Apis::DriveV3::File.new(starred: true),
          fields: "id,name,mimeType,owners(emailAddress),shortcutDetails(targetId,targetMimeType)"
        )
        remove_403_error_for_target_of_shortcut(file)
        log_shortcut_details(file)
        record_file_if_unowned(file)
      rescue => error
        ErrorReporter.instance.report(error, data: {file_id: file_id})
        Rails.logger.error("[GDrive] Error #{error.inspect} marking file #{file_id} as starred")

        # If we have hit the (MAX_ERRORS + 1)th error, don't save it. We only report out MAX_ERRORS errors.
        # We will stop processing in the main loop as soon as we return.
        self.error_count += 1
        return if error_count > MAX_ERRORS
        batch.http_errors ||= []
        batch.http_errors << {id: file_id, name: pick_data["name"], message: error.to_s}
        batch.http_errors.last[:from_unstarred_list] = true if from_unstarred_list
        batch.save!
      end
    end

    def log_shortcut_details(file)
      return if file.shortcut_details.nil?
      Rails.logger.info("[GDrive] File #{file.id} has shortcut details: #{file.shortcut_details}")
    end

    def record_file_if_unowned(file)
      return if file.owners.any? { |o| o.email_address == gdrive_config.google_id }
      owners = file.owners.map(&:email_address).join(",")
      Rails.logger.info("[GDrive] File #{file.id} is owned by #{owners}, saving record")
      unowned_file = UnownedFile.create_with(
        owner: owners,
        data: {name: file.name, mime_type: file.mime_type, shortcut_details: file.shortcut_details}
      ).find_or_create_by!(
        gdrive_config: gdrive_config,
        external_id: file.id
      )
      unless unowned_file.id_previously_changed?
        Rails.logger.info("[GDrive] File #{file.id} already had UnownedFile record")
      end
    end

    # If the user selects a shortcut, the ID of the linked-to file will be sent to this job, not
    # this ID of the shortcut. We will try to star the linked-to file (it may already have a star
    # if it was already selected, or it may not). The shortcut will remain unstarred, even though we will
    # have access to it. So each time we run this job, we check for any unstarred files that we
    # have access to and ingest them. Otherwise, the shortcuts will keep appearing in the picker.
    def star_any_unstarred_files
      page_token = nil
      loop do
        result = wrapper.service.list_files(q: "starred = false", page_size: 1000, page_token: page_token)
        if result.files.any?
          Rails.logger.info("[GDrive] Ingesting #{result.files.size} unstarred but accessible files")
          result.files.each do |file|
            Rails.logger.info("[GDrive] File #{file.id} is accessible but not starred, ingesting")
            ingest_file(file.id, from_unstarred_list: true)
          end
        end
        break if result.next_page_token.nil?
        page_token = result.next_page_token
      end
    end

    # If we ingest a file and it is a shortcut to a file that we've just seen a 403 error for,
    # we can assume the error was because the user actually selected the shortcut itself, so we don't
    # report that error.
    def remove_403_error_for_target_of_shortcut(file)
      return unless file.mime_type == "application/vnd.google-apps.shortcut"
      batch.http_errors.reject! do |error|
        error["id"] == file.shortcut_details.target_id && error["message"].include?("access to the file")
      end
      batch.save!
    end
  end
end
