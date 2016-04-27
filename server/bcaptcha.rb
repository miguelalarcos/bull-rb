require 'digest'
require 'eventmachine'
require 'em-http-request'

module CreateUserIfNotExist
  def create_user_if_not_exist user, password
    rpc_user_exist?(user) do |flag|
      if flag
        yield false
      else
        password = BCrypt::Password.create(password)
        $r.table('user').insert(user: user, password: password, roles: []).em_run(@conn) do |response|
          @user_id = user
          yield true
        end
      end
    end
  end
end

module NetCaptcha
  include CreateUserIfNotExist

  def get_text secret, random, alphabet='abcdefghijklmnopqrstuvwxyz', character_count = 6

    if character_count < 1 || character_count > 16
      raise "Character count of #{character_count} is outside the range of 1-16"
    end

    input = "#{secret}#{random}"

    if alphabet != 'abcdefghijklmnopqrstuvwxyz' || character_count != 6
      input <<  ":#{alphabet}:#{character_count}"
    end

    bytes = Digest::MD5.hexdigest(input).slice(0..(2*character_count - 1)).scan(/../)
    text = ''

    bytes.each do |byte|
      text << alphabet[byte.hex % alphabet.size].chr
    end

    text
  end

  def rpc_net_challenge
    random_text = [*('a'..'z')].sample(8).join
    url = "http://image.captchas.net/?client=demo&random=#{random_text}"
    @challenge_response = get_text 'secret', random_text
    yield url
  end

  def rpc_create_user_net_challenge user, password, challenge_response
    if @challenge_response == challenge_response
      create_user_if_not_exist(user, password) do |response|
        yield response
      end
      #rpc_user_exist?(user) do |flag|
      #  if flag
      #    yield false
      #  else
      #    password = BCrypt::Password.create(password)
      #    $r.table('user').insert(user: user, password: password, roles: []).em_run(@conn) do |response|
      #      @user_id = user
      #      yield true
      #    end
      #  end
      #end
    else
      yield false
    end
  end
end

module TextCaptcha
  include CreateUserIfNotExist

  def rpc_text_challenge
    http = EventMachine::HttpRequest.new('http://api.textcaptcha.com/miguel@mail.com.json').get

    http.callback do
      response = JSON.parse http.response
      @challenge_response = response['a']
      yield response['q']
    end
  end

  def rpc_create_user_text_challenge user, password, challenge_response
    md5 = Digest::MD5.new
    md5 << challenge_response
    print md5
    print @challenge_response
    if !@challenge_response.any? {|v| md5 == v}
      yield false
    else
      create_user_if_not_exist(user, password) do |response|
        yield response
      end
    end
  end
end
