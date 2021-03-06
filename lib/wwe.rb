require 'fileutils'

class WWE
  COOKIES_FILE = Rails.root.join("config", "wwe_cookies.yml")
  SESSION_PREFIX = Rails.root.join("config", "wwe_sesion")

  def self.login(email, password)
    cookies = Site.login_cookies(email, password)
    File.open(COOKIES_FILE, 'w') {|f| f.write cookies.to_yaml }
  end

  def self.load_cookies
    return nil if !File.exist?(COOKIES_FILE)

    cookies = YAML::load_file(COOKIES_FILE)
    if !cookies[:fprt] || !cookies[:ipid]
      File.unlink(COOKIES_FILE)
      return nil
    end
    cookies
  end

  def self.reset_login!
    File.unlink(COOKIES_FILE)
  end

  def self.load_session(cookies, id)
    path = "#{SESSION_PREFIX}_#{id}.yml"

    if File.exist?(path)
      session = YAML::load_file(path)
    else
      session = WS.create_session(cookies, id)
      File.open(path, 'w') {|f| f.write session.to_yaml }
    end

    session
  end

  def self.download(id)
    cookies = self.load_cookies
    session = self.load_session(cookies, id)

    key = ""
    iv = ""
    files = []
    target_ts = "#{id}.ts"
    target_mp4 = "#{id}.mp4"
    media = Media.new(cookies, session, id)

    media.load_playlist.items.each do |item|
      case item
      when M3u8::SegmentItem
        files.push(process_segment(media, item, key, iv))
      when M3u8::KeyItem
        iv = item.iv[2..-1]
        key = WS.load_key(cookies, session, item.uri, id).unpack("H*")[0]
      end
    end

    %x(cat #{files.join(" ")} > #{target_ts})
    %x(ffmpeg -i #{target_ts} -c copy -bsf:a aac_adtstoasc #{target_mp4})
    target_mp4
  ensure
    FileUtils.rm_f(target_ts)
    files.each do |f|
      FileUtils.rm_f(f)
    end
  end

  def self.process_segment(media, item, key, iv)
    filename = "#{SecureRandom.hex}.ts"
    filename_enc = "#{filename}.enc"
    media.download_segment(filename_enc, item.segment)
    %x(openssl aes-128-cbc -d -in #{filename_enc} -out #{filename} -K #{key} -iv #{iv})
    filename
  ensure
    FileUtils.rm_f(filename_enc)
  end

  class HTTPBase
    include HTTParty
    headers({
      "User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_4) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.96 Safari/537.36"
    })
    # debug_output $stdout
    # http_proxy "localhost", 8888

    def self.parse_query(uri)
      query = URI.parse(uri).query
      params = {}
      CGI::parse(query).map { |k, v| params[k] = v[0] }
      params
    end
  end

  class Site < HTTPBase
    base_uri "https://secure.net.wwe.com"

    def self.login_cookies(email, password)
      resp = self.get("/enterworkflow.do?flowId=account.login&forwardUrl=http%3A%2F%2Fnetwork.wwe.com")
      cookies = HTTParty::CookieHash.new
      resp.get_fields('Set-Cookie').each { |cookie| cookies.add_cookies(cookie) }

      params = {
        registrationAction: "identify",
        emailAddress: email,
        password: password,
        submitButton: ""
      }

      headers = {
        "referer" => "#{base_uri}/enterworkflow.do?flowId=account.login&forwardUrl=http%3A%2F%2Fnetwork.wwe.com",
        "Cookie" => cookies.to_cookie_string
      }

      resp = self.post("/workflow.do", body: params, headers: headers, follow_redirects: false)
      resp.get_fields('Set-Cookie').each { |cookie| cookies.add_cookies(cookie) }

      if cookies[:fprt] && cookies[:ipid]
        return cookies
      end

      raise NotLoggedIn.new(resp)
    end
  end

  class WS < HTTPBase
    base_uri "https://ws.media.net.wwe.com/ws/media/mf"

    def self.create_session(cookies, id)
      params = {
        identityPointId: cookies[:ipid],
        fingerprint: CGI::unescape(cookies[:fprt]),
        contentId: id,
        playbackScenario: "HTTP_CLOUD_WIRED",
        subject: "LIVE_EVENT_COVERAGE",
        platform: "WEB",
        frameworkURL: "https://ws.media.net.wwe.com"
      }

      headers = { "Cookie" => cookies.to_cookie_string }
      resp = self.get("/op-findUserVerifiedEvent/v-2.3", query: params, headers: headers)

      if data = resp["user_verified_media_response"]
        if data["status_code"] == "1" && data["session_key"]
          return resp.parsed_response
        end

        raise NotLoggedIn.new(resp) if data["status_code"] == "-3000"
        raise RateLimit.new(resp) if data["status_code"] == "-3500"
      end

      raise ParseError.new(resp)
    end

    def self.load_key(cookies, session, uri, id)
      params = {
        kid: parse_query(uri)["kid"],
        contentId: id,
        appAccountName: "wwe",
        playback: "HTTP_CLOUD_MOBILE",
        ipid: cookies[:ipid],
        platform: "WEB",
        sessionKey: session["user_verified_media_response"]["session_key"]
      }

      headers = { "Cookie" => cookies.to_cookie_string }
      resp = self.get("/op-generateKey/v-2.3", query: params, headers: headers)
      resp.response.body
    end
  end

  class Media < HTTPBase
    attr_accessor :headers, :master_url, :root_path, :playlist, :playlist_path

    def initialize(cookies, session, id)
      @headers = { "Cookie" => cookies.to_cookie_string }
      byebug
      url = Base64.decode64(session["user_verified_media_response"]["user_verified_event"]["user_verified_content"]["user_verified_media_item"]["url"])
      @master_url = url.split("|")[0]
      uri = URI.parse(master_url)
      uri.path = uri.path.split("/")[0..-2].join("/")
      @root_path = uri.to_s
    end

    def load_playlist
      master = M3u8::Playlist.read(self.class.get(master_url))
      hd_item = master.items.select { |i| i.is_a?(M3u8::PlaylistItem) }.sort_by(&:bandwidth).last

      self.playlist_path = hd_item.uri.split("/")[0]
      self.playlist = M3u8::Playlist.read(self.class.get("#{root_path}/#{hd_item.uri}"))
    end

    def download_segment(filename, path)
      File.open(filename, "wb") do |file|
        response = self.class.get("#{root_path}/#{playlist_path}/#{path}", stream_body: true) do |b|
          print "."
          file.write(b)
        end
      end
    end
  end

  class NotLoggedIn < StandardError; end
  class ParseError < StandardError; end
  class RateLimit < StandardError; end
end
