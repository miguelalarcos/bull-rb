class TextCaptcha < React::Component::Base

  param :change_answer

  before_mount do
    state.question! = ''
    $controller.rpc('text_challenge').then do |response|
      state.question! response
    end
  end

  def render
    div do
      div {state.question}
      input(type: :text).on(:change) do |event|
        params.change_answer.call event.target.value
      end
    end
  end

end

module MCreateUserCaptcha

  def user_class
    if state.user_exist
      'input-incorrect'
    else
      'input-successful'
    end
  end

  def password_class
    if state.password == state.rpassword && state.password != ''
      'input-successful'
    else
      'input-incorrect'
    end
  end

  def render
    div do
      div{'Create user'}
      input(class: user_class, placeholder: 'email', value: state.user).on (:change) do |event|
        state.user! event.target.value
        $controller.rpc('user_exist?', state.user).then do |response|
          state.user_exist! response
        end
      end
      br
      input(type: :password, placeholder: 'password', value: state.password).on(:change){|event| state.password! event.target.value}
      br
      input(class: password_class, type: :password, placeholder: 'repeat passsword', value: state.rpassword).on(:change){|event| state.rpassword! event.target.value}
      br
      captcha
      br
      button(class: 'button-active'){'Create user!'}.on(:click) do
        $controller.rpc(method_create_user, state.user, state.password, state.answer).then do |v|
          if v
            params.set_user.call true
            $roles = []
          end
        end
      end if !state.user_exist && state.password == state.rpassword && state.password != ''
    end
  end
end

class CreateUserTextCaptcha < React::Component::Base
  include MCreateUserCaptcha

  param :set_user

  before_mount do
    state.user! ''
    state.user_exist! true
    state.password! ''
    state.rpassword! ''
    state.answer ''
  end

  def captcha
    TextCaptcha(change_answer: lambda {|v| state.answer! v}) if !state.user_exist && state.password == state.rpassword && state.password != ''
  end

  def method_create_user
    'create_user_text_challenge'
  end

end


class NetCaptcha < React::Component::Base
  param :change_answer

  before_mount do
    state.url! = ''
    $controller.rpc('net_challenge').then do |response|
      state.url! response
    end
  end

  def render
    div do
      img(src: state.url)
      br
      input(type: :text).on(:change) do |event|
        params.change_answer.call event.target.value
      end
    end
  end
end

class CreateUserNetCaptcha < React::Component::Base
  include MCreateUserCaptcha

  param :set_user

  before_mount do
    state.user! ''
    state.user_exist! true
    state.password! ''
    state.rpassword! ''
    state.answer ''
  end

  def captcha
    NetCaptcha(change_answer: lambda {|v| state.answer! v}) if !state.user_exist && state.password == state.rpassword && state.password != ''
  end

  def method_create_user
    'create_user_net_challenge'
  end
end
