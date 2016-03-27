#require 'opal'
require 'browser'
require 'browser/socket'
require 'promise'
require 'json'

class Controller

    attr_accessor :app_rendered
    @@ticket = 0

    def initialize
        @watch = {}
        @promises = {}
        @ws = nil
        @app_rendered = false
    end

    def watch(name, *args, &block)
        id = get_ticket
        @watch[id] = {who: block, name: name, args: args}
        send('watch_' + name, id, *args)
        id
    end

    def stop_watch(id)
        @watch.delete(id)
        send('stop_watch', id)
    end

    def rpc(command, *args)
        id = get_ticket
        promise = Promise.new
        send 'rpc_'+command, id, *args
        @promises[id] = promise
        promise
    end

    def start(app)
        begin
            controller = self
            @ws = Browser::Socket.new 'ws://localhost:3000' do
                on :open do |e|
                    if !app_rendered
                        $document.ready do
                          React.render(React.create_element(app), `document.getElementById('container')`)
                          controller.app_rendered = true
                        end
                    end
                end
                on :message do |e|
                    controller.notify JSON.parse(e.data)
                end
            end            
        rescue Exception => e  
            puts e.message  
            puts e.backtrace.inspect 
            #sleep 5
            #retry
        end
        if !@watch.empty?
            @watch.each do |id, value|
                send 'watch', id, value[:name], value[:args]
            end
        end
    end

    private

        def get_ticket
            id = @@ticket
            @@ticket += 1
            id
        end

        def send(command, id, *args, **kwargs)
            @ws.send({command: command, id: id, args: args, kwargs: kwargs}.to_json)
            # @ws.send_data [command, args].to_json
        end

        def notify msg
            puts msg
            if msg['response'] == 'watch'
                handle_watch_data msg['id'], msg['data']
            elsif msg['response'] == 'rpc'
                handle_rpc_result msg['id'], msg['result']
            end
        end

        def handle_watch_data(id, data)
            w = @watch[id]
            if w
                w[:who].call data
            end
        end

        def handle_rpc_result(id, result)
            @promises[id].resolve result
            @promises.delete id
        end

        def reset
            @watch.each_value do |value|
                value[:who].notify nil
            end
            start nil
        end
end
