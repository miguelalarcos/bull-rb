require 'ui_core'
require 'notification'
require 'mrelogin'

class Relogin < React::Component::Base

  include MRelogin
  before_mount do
    state.password! ''
    state.show! false
    MRelogin.panel = self
  end

  def show_relogin val
    state.show! val
  end

  def render
    div do
      div do
        PasswordInput(on_change: lambda{|v| state.password! v}, value: state.password)
        button{'relogin'}.on(:click) do
          $controller.relogin state.password
        end
      end if state.show
    end
  end
end

class Login < React::Component::Base
  param :set_user
  param :set_roles

  before_mount do
    state.user_name! ''
    state.password! ''
    state.incorrect! false
  end

  def render
    div do
      StringInput(on_change: lambda {|v| state.user_name! v}, value: state.user_name)
      PasswordInput(on_change: lambda {|v| state.password! v}, value: state.password)
      button(type: :button) { 'login' }.on(:click) do
        $controller.login(state.user_name, state.password).then do |roles|
          if roles
            state.incorrect! false
            params.set_user.call state.user_name #true
            params.set_roles.call roles
          else
            state.incorrect! true
          end
        end
      end
      div(class: 'red'){'Incorrect user or password.'} if state.incorrect
    end
  end
end

class ForgottenPassword < React::Component::Base
  param :klass

  before_mount do
    state.email! ''
  end

  def render
    div(class: params.klass) do
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

  include MNotification

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
    div(class: params.klass) do
      div{'Create user'}
      input(class: user_class, placeholder: 'email', value: state.user).on (:change) do |event|
        state.user! event.target.value
        $controller.rpc('user_exist?', state.user).then do |response|
          state.user_exist! response
        end
      end
      div{
        input(type: :password, placeholder: 'password', value: state.password).on(:change){|event| state.password! event.target.value}
      }
      div{
        input(class: password_class, type: :password, placeholder: 'repeat passsword', value: state.rpassword).on(:change){|event| state.rpassword! event.target.value}
      }
      captcha if !state.user_exist && state.password == state.rpassword && state.password != ''
      div{
        button{'send me the code'}.on(:click){$controller.task('send_code_to_email', state.user, state.answer)}
        input(placeholder: 'code sent to your email', value: state.code).on(:change){|event| state.code! event.target.value}
      } if state.user && state.answer
      div do
        button(class: 'button-active'){'Create user!'}.on(:click) do
          $controller.rpc(method_create_user, state.user, state.password, state.answer, state.code).then do |v|
            if v
              params.set_user.call state.user #true
              params.set_roles.call []
              $user_id = state.user
              notify_ok 'user created', 1
            else
              notify_error 'error creating user', 1
            end
          end
        end if !state.user_exist && state.password == state.rpassword && state.password != '' and state.code
      end
    end
  end
end

=begin
class CreateUserWithoutCaptcha < React::Component::Base
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
    div
  end

  def method_create_user
    'create_user_email_code'
  end

end
=end

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
    TextCaptcha(change_answer: lambda {|v| state.answer! v})
  end

  def method_create_user
    'create_user_text_challenge'
  end

end

class CreateUserNetCaptcha < React::Component::Base
  include CreateUserCaptcha

  param :set_user
  param :set_roles
  param :klass

  before_mount do
    state.user! ''
    state.user_exist! true
    state.password! ''
    state.rpassword! ''
    state.answer ''
    state.code! ''
  end

  def captcha
    NetCaptcha(change_answer: lambda {|v| state.answer! v})
  end

  def method_create_user
    'create_user_net_challenge'
  end
end
