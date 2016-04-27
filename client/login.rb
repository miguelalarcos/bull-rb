require 'ui_core'

class Relogin < React::Component::Base
  def render
    PasswordInput(on_change: lambda{|v| state.password = v}, value: state.password)
    button{'relogin'}.on(:click){$controller.relogin state.password}
  end
end

class Login < React::Component::Base
  param :set_user
  param :set_roles

  before_mount do
    state.user_name! ''
    state.password! ''
    state.incorrect = false
  end

  def render
    div do
      StringInput(on_change: lambda {|v| state.user_name! v}, value: state.user_name)
      PasswordInput(on_change: lambda {|v| state.password! v}, value: state.password)
      button(type: :button) { 'login' }.on(:click) do
        $controller.rpc('login', state.user_name, state.password).then do |roles|
          if roles
            state.incorrect = false
            $user_id = state.user_name
            params.set_user.call true
            params.set_roles.call roles
          else
            state.incorrect = true
          end
        end
      end
      div(class: 'red'){'Incorrect user or password.'}
    end
  end
end

class ForgottenPassword < React::Component::Base

  before_mount do
    state.email! ''
  end

  def render
    div do
      div{'Have you forgotten the password?'}
      StringInput(placeholder: 'email', on_change: lambda{|v| state.email! v}, value: state.email)
      button{'Send me a new passoword'}.on(:click){$controller.task('forgotten_password', state.email)} if state.email
    end
  end
end

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

module CreateUserCaptcha

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
      button{'send me the code'}.on(:click){$controller.task('send_code_to_email', state.user)}
      div{
        input(type: :password, placeholder: 'password', value: state.password).on(:change){|event| state.password! event.target.value}
      }
      div{
        input(class: password_class, type: :password, placeholder: 'repeat passsword', value: state.rpassword).on(:change){|event| state.rpassword! event.target.value}
      }
      div{
        input(placeholder: 'code sent to your email', value: state.code).on(:change){|event| state.code! event.target.value}
      }
      captcha
      div do
        button(class: 'button-active'){'Create user!'}.on(:click) do
          $controller.rpc(method_create_user, state.user, state.password, state.answer, state.code).then do |v|
            if v
              params.set_user.call true
              params.set_roles.call []
              $user_id = state.user
            end
          end
        end if !state.user_exist && state.password == state.rpassword && state.password != '' and state.code
      end
    end
  end
end

class CreateUserTextCaptcha < React::Component::Base
  include CreateUserCaptcha

  param :set_user
  param :set_roles

  before_mount do
    state.user! ''
    state.user_exist! true
    state.password! ''
    state.rpassword! ''
    state.answer ''
    state.code! ''
  end

  def captcha
    TextCaptcha(change_answer: lambda {|v| state.answer! v}) if !state.user_exist && state.password == state.rpassword && state.password != ''
  end

  def method_create_user
    'create_user_text_challenge'
  end

end

class CreateUserNetCaptcha < React::Component::Base
  include CreateUserCaptcha

  param :set_user
  param :set_roles

  before_mount do
    state.user! ''
    state.user_exist! true
    state.password! ''
    state.rpassword! ''
    state.answer ''
    state.code! ''
  end

  def captcha
    NetCaptcha(change_answer: lambda {|v| state.answer! v}) if !state.user_exist && state.password == state.rpassword && state.password != ''
  end

  def method_create_user
    'create_user_net_challenge'
  end
end
