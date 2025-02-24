# frozen_string_literal: true

class MovePaperclipFiles < ActiveRecord::Migration[6.0]
  def up
    ActsAsTenant.without_tenant do
      ActiveStorage::Attachment.find_each do |attachment|
        name = attachment.name

        source = attachment.record.send(name).path
        dest_dir = File.join(
          "storage",
          attachment.blob.key.first(2),
          attachment.blob.key.first(4).last(2)
        )
        dest = File.join(dest_dir, attachment.blob.key)

        FileUtils.mkdir_p(dest_dir)
        puts "Copying #{source} to #{dest}"
        FileUtils.cp(source, dest)
      end
    end
  end
end
