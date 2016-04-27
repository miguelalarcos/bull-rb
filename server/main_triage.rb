require './server'

class MyController < BullServerController
  #def initialize ws, conn
  #  super ws, conn
  #end

  def before_insert_triage doc
    true
  end

  def before_update_triage old, new, merged
    true
  end

  def rpc_get_triage id
    check id, String
    get('triage', id) {|doc| yield doc}
  end

  def watch_triage
    $r.table('triage')
  end

end