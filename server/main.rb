require './server'
require 'em-synchrony'
require '../validation/validation'

class MyController < Bull::Controller

  def initialize ws, conn
    super ws, conn
    @mutex = EM::Synchrony::Thread::Mutex.new
  end

  def rpc_add a, b
    @mutex.synchronize do
      a + b
    end
  end

  def rpc_get_i18n id
    get 'i18n', id
    #$r.table('i18n').get(id).run(@conn)
  end

  def rpc_get_car id
    get 'car', id
    #$r.table('car').get(id).run(@conn)
  end

  def watch_car id
    $r.table('car').get(id) #.changes({include_initial: true})
  end

  #def before_watch_by_id_car doc
  #  user_is_owner? doc
  #end

  def watch_cars_of_color color
    $r.table('car').filter(color: color) #.changes({include_initial: true})
  end

  def before_update_car old_val, new_val, merged
    if !ValidateCar.new.validate merged
    #if !ValidateCar.new.validate old_val.merge(new_val)
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

