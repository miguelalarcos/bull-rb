require 'eventmachine'
require 'em-websocket'
#require './main_demo'
require '../../app/server/main'
require 'rethinkdb'
require '../conf'
require 'time'
require './mreport'

puts Time.now
MReport.load_reports

$r = RethinkDB::RQL.new
conn = $r.connect()

EM.run do
  EM::WebSocket.run(:host => "0.0.0.0",
                    :port => 3000
                    #:secure => true,
                    #:tls_options => {
                    #  :private_key_file => "../privateKey.key",
                    #  :cert_chain_file => "../certificate.crt"
                    #}
                    ) do |ws|
    controller = nil

    ws.onopen { |handshake| controller = AppController.new ws, conn}

    ws.onmessage do |msg|
      begin
        controller.notify msg
      rescue Exception => e
        puts 'message: ', e.message
        puts 'trace: ', e.backtrace.inspect
      end
    end

    ws.onclose { controller.close; controller = nil }

    ws.onerror { |e| controller = nil; puts "Error: #{e.message}"}
  end
end
