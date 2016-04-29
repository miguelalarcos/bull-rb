require './server'
require '../validation/validation_demo'

class AppController < BullServerController

  def rpc_location loc
    check loc, String
    get_array(
        $r.table('location').filter do |doc|
          doc['name'] =~ /#{loc}/i
        end
    ) {|docs| yield docs}
  end

  def before_insert_demo doc
    ValidateDemo.new.validate doc
  end

  def before_update_demo old, new, merged
    ValidateDemo.new.validate merged
  end

  def get_unique_i18n(lang:)
    get_unique('i18n', {lang: lang}) {|doc| yield doc}
  end

  def rpc_get_demo id
    get('demo', id) {|doc| yield doc}
  end

  def watch_demo id
    check id, String
    if !id.nil?
      $r.table('demo').get(id)
    end
  end

  def watch_demo_items
    $r.table('demo')
  end

end

