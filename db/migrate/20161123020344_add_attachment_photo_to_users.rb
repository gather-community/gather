class AddAttachmentPhotoToUsers < ActiveRecord::Migration[4.2]
  def self.up
    change_table :users do |t|
      t.attachment :photo
    end
  end

  def self.down
    remove_attachment :users, :photo
  end
end
