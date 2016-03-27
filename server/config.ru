require 'faye/websocket'
Faye::WebSocket.load_adapter('thin')

require './main'
require 'rethinkdb'
#include RethinkDB::Shortcuts

$r = RethinkDB::RQL.new
conn = $r.connect()

App = lambda do |env|
  if Faye::WebSocket.websocket?(env)
    ws = Faye::WebSocket.new(env)
    
    controller = MyController.new ws, conn        

    ws.on :message do |event|      
      puts '--> ' + event.data      
      controller.notify event.data
    end

    ws.on :close do |event|
      puts 'closing', event.code, event.reason
      controller.close
      ws = nil
    end

    ws.rack_response
  end
end


map '/' do
    run App
end