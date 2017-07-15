module PhotoDestroyable
  extend ActiveSupport::Concern

  included do
    attr_accessor :photo_destroy

    before_save do
      photo.destroy if photo_destroy?
    end
  end

  def photo_destroy?
    photo_destroy.to_i == 1
  end
end
