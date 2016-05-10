require './server'
require './bcaptcha'
require '../validation/validation_demo'

class AppController < BullServerController

  include NetCaptcha

  def rpc_report_demo id
    check id, String
    doc = get('demo', id, symbolize=false)
    t = reports['demo']
    t.render(doc)
  end

  def rpc_location loc
    check loc, String
    pred = $r.table('location').filter do |doc|
      doc['name'].match("(?i).*" + loc + ".*")
    end
    docs = rmsync pred
    docs.collect{|x| x[:name]}
  end

  def before_insert_demo doc
    ValidateDemo.new.validate doc
  end

  def before_update_demo old, new, merged
    ValidateDemo.new.validate merged
  end

  def before_delete_demo id
    true
  end

  def rpc_get_unique_i18n(lang)
    check lang, String
    get_unique('i18n', {lang: lang}) #{|doc| yield doc}
  end

  def rpc_get_demo id
    check id, String
    get('demo', id) #{|doc| yield doc}
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

