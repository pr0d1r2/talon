require_dependency "rate_limiter"

module Auth; end
class Auth::CurrentUserProvider
  CURRENT_USER_KEY ||= "_TALON_CURRENT_USER".freeze
  API_KEY ||= "api_key".freeze
  HTTP_API_KEY ||= "HTTP_API_KEY".freeze
  API_KEY_ENV ||= "_TALON_API".freeze
  TOKEN_COOKIE ||= "_t".freeze
  PATH_INFO ||= "PATH_INFO".freeze
  COOKIE_ATTEMPTS_PER_MIN ||= 10

  # do all current user initialization here
  def initialize(env)
    @env = env
    @request = Rack::Request.new(env)
  end

  # our current user, return nil if none is found
  def current_user
    return @env[CURRENT_USER_KEY] if @env.key?(CURRENT_USER_KEY)

    # bypass if we have the shared session header
    if shared_key = @env['HTTP_X_SHARED_SESSION_KEY']
      uid = $redis.get("shared_session_key_#{shared_key}")
      user = nil
      if uid
        user = User.find_by(id: uid.to_i)
      end
      @env[CURRENT_USER_KEY] = user
      return user
    end

    request = @request
    api_key =  @env[HTTP_API_KEY] || request[API_KEY]
    auth_token = request.cookies[TOKEN_COOKIE] unless api_key
    current_user = nil

    if auth_token && auth_token.length == 32
      limiter = RateLimiter.new(nil, "cookie_auth_#{request.ip}", COOKIE_ATTEMPTS_PER_MIN, 60)

      if limiter.can_perform?
        @user_token = UserAuthToken.lookup(auth_token,
                                           seen: true,
                                           user_agent: @env['HTTP_USER_AGENT'],
                                           path: @env['REQUEST_PATH'],
                                           client_ip: @request.ip)

        current_user = @user_token.try(:user)
      end

      unless current_user
        begin
          limiter.performed!
        rescue RateLimiter::LimitExceeded
          raise Talon::InvalidAccess
        end
      end
    end

    if current_user && should_update_last_seen?
      u = current_user
      Rufus::Scheduler.singleton.in '1s' do
        u.update_last_seen!
        u.update_ip_address!(request.ip)
      end
    end

    # possible we have an api call, impersonate
    if api_key
      current_user = lookup_api_user(api_key, request)
      raise Talon::InvalidAccess unless current_user
      raise Talon::InvalidAccess if !current_user.shadow && (current_user.suspended || !current_user.active)
      @env[API_KEY_ENV] = true
    end

    # keep this rule here as a safeguard
    # no user for suspended or inactive accounts unless shadow account
    if current_user && !current_user.shadow && (current_user.suspended || !current_user.active)
      current_user = nil
    end

    @env[CURRENT_USER_KEY] = current_user
  end

  def refresh_session(user, session, cookies)
    # if user was not loaded, no point refreshing session
    # it could be an anonymous path, this would add cost
    return if is_api? || !@env.key?(CURRENT_USER_KEY)

    if @user_token && @user_token.user == user
      rotated_at = @user_token.rotated_at

      needs_rotation = @user_token.auth_token_seen ? rotated_at < UserAuthToken::ROTATE_TIME.ago : rotated_at < UserAuthToken::URGENT_ROTATE_TIME.ago

      if needs_rotation
        if @user_token.rotate!(user_agent: @env['HTTP_USER_AGENT'],
                              client_ip: @request.ip,
                              path: @env['REQUEST_PATH'])
          cookies[TOKEN_COOKIE] = cookie_hash(@user_token.unhashed_auth_token)
        end
      end
    end

    if !user && cookies.key?(TOKEN_COOKIE)
      cookies.delete(TOKEN_COOKIE)
    end
  end

  def log_on_user(user, session, cookies)
    @user_token = UserAuthToken.generate!(user_id: user.id,
                                          user_agent: @env['HTTP_USER_AGENT'],
                                          path: @env['REQUEST_PATH'],
                                          client_ip: @request.ip)

    cookies[TOKEN_COOKIE] = cookie_hash(@user_token.unhashed_auth_token)
    make_developer_admin(user)
    @env[CURRENT_USER_KEY] = user
  end

  def cookie_hash(unhashed_auth_token)
    hash = {
      value: unhashed_auth_token,
      httponly: true,
      expires: Settings.maximum_session_age.hours.from_now,
      secure: Settings.force_https
    }

    if Settings.same_site_cookies != "Disabled"
      hash[:same_site] = Settings.same_site_cookies
    end

    hash
  end

  def make_developer_admin(user)
    if  user.active? &&
        !user.admin &&
        Settings.developer_emails.include?(user.email)
      user.admin = true
      user.save
    end
  end

  def log_off_user(session, cookies, strict)
    user = current_user
    if strict && user
      user.user_auth_tokens.destroy_all

      if user.admin && defined?(Rack::MiniProfiler)
        # clear the profiling cookie to keep stuff tidy
        cookies.delete("__profilin")
      end

      user.logged_out
    elsif user && @user_token
      @user_token.destroy
    end
    cookies.delete(TOKEN_COOKIE)
  end

  # api has special rights return true if api was detected
  def is_api?
    current_user
    !!(@env[API_KEY_ENV])
  end

  def has_auth_cookie?
    cookie = @request.cookies[TOKEN_COOKIE]
    !cookie.nil? && cookie.length == 32
  end

  def should_update_last_seen?
    true
  end

  protected

  def lookup_api_user(api_key_value, request)
    User.where(api_key: api_key_value).first
  end
end
