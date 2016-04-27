require './server'

class MyController < BullServerController
  #def initialize ws, conn
  #  super ws, conn
  #end

  def before_insert_triage doc
    @roles.include? 'administrativo'
  end

  def before_update_triage old, new, merged
    if new[:observations].nil?
      @roles.include? 'administrativo'
    else
      @roles.include? 'nurse'
    end
  end

  def rpc_get_triage id
    check id, String
    get('triage', id) {|doc| yield doc}
  end

  def watch_triage
    $r.table('triage')
  end

  def search_patient nhc, name
    check nhc, Integer
    check name, String
    get_array(
        $r.table('patient').filter do |patient|
          patient['nhc'] == nhc | patient['name'].match("(?i).*"+name+".*")
        end
    ){|docs| yield docs}
  end
end