require './server'
require 'liquid'

class MyController < Bull::Controller
  def initialize ws, conn
    super ws, conn
  end

  def before_insert_my_table doc
    true
  end

  def before_update_my_table old, new, merged
    true
  end

  def rpc_get_my_table id
    check id, String
    if id.nil?
      yield Hash.new
    else
      get('my_table', id) {|doc| yield doc}
    end
  end

  def watch_my_table
    $r.table('my_table')
  end

end