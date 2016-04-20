require './server'
require 'em-synchrony'
#require '../validation/validation'
#require 'bcrypt'
require './bcaptcha'
require 'liquid'

class MyController < Bull::Controller

  include NetCaptcha

  def initialize ws, conn
    super ws, conn
    @mutex_store = EM::Synchrony::Thread::Mutex.new
  end

  def task_store id, quantity, price, unit
    check id, String
    check quantity, Integer
    check price, Float
    check unit, String

    @mutex_store.synchronize do
      $r.table('item').get(id).update do |doc|
        {:quantity=>doc['quantity']+quantity, :price=>price, :unit=>unit}
      end.em_run(@conn){}
    end
  end

  def task_sale id, quantity, price, unit
    check id, String
    check quantity, Integer
    check price, Float
    check unit, String

    @mutex_store.synchronize do
      $r.table('item').get(id).em_run(@conn) do |doc|
        if doc['quantity'] >= quantity
          $r.table('item').get(id).update do |doc|
            {:quantity=>doc['quantity']-quantity}
          end.em_run(@conn){}
          $r.table('line').insert(:item_id=>id, :item_name=>doc['name'],
                                  :quantity=>quantity, :price=>price, :unit=>unit).em_run(@conn){}
        end
      end
    end
  end

  def task_cancel_line id
    check id, String
    @mutex_store.synchronize do
      $r.table('line').get(id).em_run(@conn) do |line|
        $r.table('item').update do |item|
          {:quantity=>item['quantity']+line['quantity']}
        end.em_run(@conn){}
        $r.table('line').get(id).delete.em_run(@conn){}
      end
    end
  end

  def watch_lines
    $r.table('line')#.filter(order_code: code)
  end

  def watch_items
    $r.table('item')
  end

  def before_insert_item doc
    true
  end

  def before_update_item old_val, new_val, merged
    true
  end

end