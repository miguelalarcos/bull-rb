require './server'

class MyController < BullServerController
  #def initialize ws, conn
  #  super ws, conn
  #end

  def get_unique_user key, value
    check key, String
    check value, String
    if @roles.include? 'admin'
      get_unique('user', {"#{key}" => value}){|doc| doc.delete 'password'; yield doc}
    else
      yield Hash.new
    end
  end

  def before_insert_triage doc
    @roles.include? 'administrative'
  end

  def before_update_triage old, new, merged
    if new[:observations].nil?
      @roles.include? 'administrative'
    else
      @roles.include? 'nurse'
    end
  end

  def rpc_get_triage id
    check id, String
    get('triage', id)  do |doc|
      if @roles.include? 'nurse'
        yield doc
      else
        doc.delete 'observations'
        yield doc
      end
    end
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

