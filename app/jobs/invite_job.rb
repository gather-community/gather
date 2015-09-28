# Sends invites to the users with the given IDs.
InviteJob = Struct.new(:user_ids) do
  def perform
    @users = User.find(user_ids)
    @users.each{ |u| u.send_reset_password_instructions }
  end

  def max_attempts
    3
  end

  def error(job, exception)
    ExceptionNotifier.notify_exception(exception, data: {user_ids: user_ids})
  end
end
