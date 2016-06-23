require 'opal'

run Opal::Server.new { |s|

  #s.append_path '/home/miguel/.rvm/gems/ruby-2.2.2/gems'
  s.append_path '.'
  s.append_path '..'
  s.append_path '../../app'
  s.append_path '../../app/client'

  s.debug = true
  s.source_map_enabled
  s.index_path = 'index.html'
  s.main = '../../app/client/main'

}
