require './server'
require 'em-synchrony'

class MyController < Controller

  def initialize ws, conn
    super ws, conn
    @mutex = EM::Synchrony::Thread::Mutex.new
  end

  def rpc_add a, b
    @mutex.synchronize do
      a + b
    end
  end

  def before_watch_by_id_car doc
    user_is_owner? doc
  end

  def watch_cars_of_color color
    $r.table('car').changes({include_initial: true}).filter do |row|
      (row[:new_val][:color] == color) | (row[:old_val][:color] == color)
    end
  end

  def before_update_car old_val, new_val
    u_timestamp! new_val
    true
    #user_role_in? old_val
  end

  def before_insert_car doc
    if user_roles.include? 'writer'
      i_timestamp! doc
      owner! doc
      true
    else
      false
    end
  end
end

