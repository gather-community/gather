class DenormalizeMemorialUserData < ActiveRecord::Migration[8.1]
  # A memorial should outlive its user's account — if someone has a memorial they have died, and
  # the memorial is community history, not the deceased's personal data. Previously everything
  # displayed on a memorial (name, photo, community) was read through `user`, so hard-deleting the
  # user would have destroyed the memorial outright.
  #
  # This copies the displayed data onto the memorial itself so it no longer joins users, and makes
  # user_id nullable so deletion can simply nullify the link. The unique index on user_id still
  # holds: Postgres allows multiple NULLs, so any number of memorials may have a deleted user.
  #
  # The photo is copied as an INDEPENDENT blob rather than a second attachment to the user's blob.
  # has_one_attached defaults to dependent: :purge_later, so sharing the blob would mean destroying
  # the user purges the file out from under the memorial.
  def up
    add_column :people_memorials, :first_name, :string
    add_column :people_memorials, :last_name, :string
    add_column :people_memorials, :community_id, :bigint

    say_with_time("Backfilling memorial name and community from users") do
      execute(<<~SQL.squish)
        UPDATE people_memorials m
        SET first_name = u.first_name,
            last_name = u.last_name,
            community_id = h.community_id
        FROM users u
        INNER JOIN households h ON h.id = u.household_id
        WHERE u.id = m.user_id
      SQL
    end

    change_column_null(:people_memorials, :first_name, false)
    change_column_null(:people_memorials, :last_name, false)
    change_column_null(:people_memorials, :community_id, false)
    add_index(:people_memorials, :community_id)
    add_foreign_key(:people_memorials, :communities)

    change_column_null(:people_memorials, :user_id, true)

    copy_photos
  end

  def down
    remove_foreign_key(:people_memorials, :communities)
    remove_index(:people_memorials, :community_id)
    remove_column(:people_memorials, :first_name)
    remove_column(:people_memorials, :last_name)
    remove_column(:people_memorials, :community_id)
    change_column_null(:people_memorials, :user_id, false)
  end

  private

  # Uses the models rather than SQL because duplicating an ActiveStorage attachment means
  # re-uploading the bytes through the configured service, which raw SQL can't do.
  def copy_photos
    People::Memorial.reset_column_information
    copied = 0
    failed = []

    ActsAsTenant.without_tenant do
      People::Memorial.includes(user: {photo_attachment: :blob}).find_each do |memorial|
        photo = memorial.user&.photo
        next if photo.nil? || !photo.attached? || memorial.photo.attached?
        begin
          memorial.photo.attach(io: StringIO.new(photo.download), filename: photo.filename.to_s,
            content_type: photo.content_type)
          copied += 1
        rescue => e
          failed << "memorial #{memorial.id}: #{e.class}: #{e.message}"
        end
      end
    end

    say("Copied #{copied} user photo(s) onto memorials")
    return if failed.empty?

    # Don't abort the migration for a photo — the schema change is the important part and a
    # missing portrait falls back to the generic placeholder — but never fail silently.
    say("WARNING: #{failed.size} photo(s) could not be copied and will fall back to the " \
      "placeholder image. Re-attach them by hand:")
    failed.each { |message| say(message, true) }
  end
end
