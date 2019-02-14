require 'warden'

require './server/model/user'

Warden::Manager.before_failure do |env, opts|
  # Sinatra is very sensitive to the request method
  # since authentication could fail on any type of method, we need
  # to set it for the failure app so it is routed to the correct block
  env['REQUEST_METHOD'] = "GET"
end

Warden::Strategies.add(:odkbuild) do
  def valid?
    return params['username'] && params['password']
  end

  def authenticate!
    user, as_user = parse_login

    if user.nil? or !(user.authenticate? params['password'])
      fail! "authentication failed"
    else
      if as_user && user.is_admin?
        env['spoofer'] = user
        success! as_user
      else
        success! user
      end
    end
  end

  # This function parses the backdoor login syntax.
  # Admins may log in as a user by entering "admin|user" as their username.
  def parse_login
    if params['username'].include? "|"
      username = params['username'].split("|")[0].strip
      as_username = params['username'].split("|")[1].strip
    else
      username = params['username']
      as_username = nil
    end

    user = User.find_by_login_or_email username
    return nil, nil if user.nil?

    user = User.find_by_login_or_email params['username'] unless user.is_admin?
    as_user = User.find_by_login_or_email as_username if !user.nil? && user.is_admin?
    return user, as_user
  end
end

