# frozen_string_literal: true

# == Schema Information
#
# Table name: people_memorials
#
#  id           :bigint           not null, primary key
#  birth_year   :integer
#  cluster_id   :bigint           not null
#  community_id :bigint           not null
#  created_at   :datetime         not null
#  death_year   :integer          not null
#  first_name   :string           not null
#  last_name    :string           not null
#  obituary     :text
#  updated_at   :datetime         not null
#  user_id      :bigint
#
module People
  # A memorial outlives the account it was created from. Name, community, and photo are copied
  # from the user when the memorial is created (or repointed) so that nothing here reads through
  # `user` — hard-deleting the account just nullifies user_id and the memorial stands on its own.
  class Memorial < ApplicationRecord
    acts_as_tenant :cluster

    belongs_to :user, inverse_of: :memorial, optional: true
    belongs_to :community
    has_many :messages, class_name: "People::MemorialMessage", inverse_of: :memorial, dependent: :destroy
    has_one_attached :photo

    scope :in_community, ->(c) { where(community: c) }
    scope :by_name, -> { alpha_order(:first_name).alpha_order(:last_name) }

    normalize_attributes :obituary

    validates :birth_year, :death_year, :first_name, :last_name, presence: true
    # Only one memorial per live account. Deleted accounts leave user_id NULL, and Postgres allows
    # any number of NULLs in a unique index, so memorials pile up there harmlessly.
    validates :user_id, uniqueness: true, allow_nil: true

    before_validation :copy_user_attributes, if: :user_id_changed?
    after_save :copy_user_photo, if: :saved_change_to_user_id?

    def name
      "#{first_name} #{last_name}"
    end

    # copy_user_attributes runs on validation, but assign_attributes doesn't validate and Pundit
    # authorizes before save — so fall back to the user's community until the copy has happened.
    def community
      super || user&.community
    end

    private

    def copy_user_attributes
      return if user.nil?
      self.first_name = user.first_name
      self.last_name = user.last_name
      self.community_id = user.community_id
    end

    # Copied as an independent blob: has_one_attached defaults to dependent: :purge_later, so
    # attaching the user's own blob would mean destroying the user purges the memorial's photo too.
    def copy_user_photo
      return if user.nil? || !user.photo.attached?
      photo.attach(io: StringIO.new(user.photo.download), filename: user.photo.filename.to_s,
        content_type: user.photo.content_type)
    rescue ActiveStorage::FileNotFoundError => error
      # The attachment row outlived its file. The memorial still stands, just with the generic
      # placeholder portrait — much better than refusing to save it at all.
      Gather::ErrorReporter.instance.report(error, data: {memorial_id: id, user_id: user_id})
    end
  end
end
