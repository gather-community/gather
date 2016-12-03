class UploadPolicy < ApplicationPolicy
  def create?
    active?
  end

  # This may seem counterintuitive, but any active user can destroy an upload because
  # they need to know the tmp_id in order to do so, and so the tmp_id functions somewhat like
  # a session key. If you know the secret, you can delete the upload.
  def destroy?
    active?
  end
end
