require './server'
require 'em-synchrony'
require '../validation/validation'
require 'bcrypt'
require './bcaptcha'
require 'liquid'

class MyController < Bull::Controller

  #include TextCaptcha
  include NetCaptcha

  def initialize ws, conn
    super ws, conn
    @mutex = EM::Synchrony::Thread::Mutex.new
  end

  def rpc_get_ticket
    @mutex.synchronize do
      $r.table('ticket').get('0').em_run(@conn) do|doc|
        $r.table('ticket').get('0').update({value: doc['value'] + 1}).em_run(@conn) do
          yield doc['value']
        end
      end
    end
  end


  def rpc_print_car id
    check id, String
    get('car', id) do |doc|
      if user_is_owner? doc
        t = $reports['car']
        yield t.render(doc)
      else
        yield ''
      end
    end
  end

  #def rpc_add a, b
  #  @mutex.synchronize do
  #    a + b
  #  end
  #end

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

  def rpc_get_clients code, surname
    get_array(
        $r.table('client').filter do |cli|
          cli['code'] == code | cli['surname'].match("(?i).*"+surname+".*")
        end
    ) {|docs| yield docs}
  end

  def watch_orders code, client_code, date
    $r.table('order').filter do |v|
      v['code'] == code | (v['client_code'] == client_code & v['date'] == date)
    end
  end

  def watch_lines_of_order code
    $r.table('line').filter(order_code: code)
  end

  def watch_car id
    $r.table('car').get(id)
  end

  def watch_cars_of_color color
    $r.table('car').filter(color: color)
  end

  def before_update_car old_val, new_val, merged
    if !ValidateCar.new.validate merged
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
    owner! doc
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

