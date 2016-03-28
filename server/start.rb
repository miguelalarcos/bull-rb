require 'eventmachine'
require 'em-websocket'
require './main'
require 'rethinkdb'

$r = RethinkDB::RQL.new
conn = $r.connect()

EM.run do
  EM::WebSocket.run(:host => "0.0.0.0", :port => 3000, :debug => true) do |ws|
    controller = nil

    ws.onopen { |handshake| controller = MyController.new ws, conn}

    ws.onmessage { |msg| controller.notify msg }

    ws.onclose { controller.close; controller = nil }

    ws.onerror { |e| controller = nil; puts "Error: #{e.message}"}
  end
end
