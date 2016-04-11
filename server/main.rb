require './server'
require 'em-synchrony'
require '../validation/validation'
require 'bcrypt'

module CreateUserTextCapcha

  def challenge
    @challenge_response = 'secret'
    yield 'question?'
  end

  def create_user_text_challenge user, password, challenge_response
    if challenge_response != @challenge_response
      yield false
    else
      user_exist?(user) do |flag|
        if flag
          yield false
        else
          password = BCrypt::Password.create(password)
          $r.table('user').insert(user: user, password: password, roles: []).em_run(@conn){|response| yield response['generated_keys'][0]}
        end
      end
    end
  end

end

class MyController < Bull::Controller

  include CreateUserTextCapcha

  def initialize ws, conn
    super ws, conn
    @mutex = EM::Synchrony::Thread::Mutex.new
  end

  def rpc_add a, b
    @mutex.synchronize do
      a + b
    end
  end

  def docs_with_count predicate
    predicate.count().em_run(@conn) do |count|
      predicate.em_run(@conn) {|doc| yield count, doc}
    end
  end

  def rpc_get_location value
    if value == ''
      yield []
    else
      ret = []
      docs_with_count($r.table('location').filter{|doc| doc['description'].match("(?i).*"+value+".*")}) do |count, row|
        ret << row
        if ret.length == count
          yield ret
          #break
        end
      end
    end
  end

  def rpc_get_i18n id
    get('i18n', id) {|doc| yield doc}
  end

  def rpc_get_car id
    get('car', id){|doc| yield doc}
  end

  def watch_car id
    $r.table('car').get(id)
  end

  def watch_cars_of_color color
    $r.table('car').filter(color: color)
  end

  def before_update_car old_val, new_val, merged
    if !ValidateCar.new(conn: @conn).validate merged
      return false
    end
    u_timestamp! merged
    true
    #user_role_in? old_val
  end

  def before_delete_car doc
    true
    #user_is_owner? doc
  end

  def before_insert_car doc
    return ValidateCar.new.validate(doc)
    if user_roles.include? 'writer' && ValidateCar.new.validate(doc)
      i_timestamp! doc
      owner! doc
      true
    else
      false
    end
  end
end

