#require 'opal'
require 'browser'
require 'browser/socket'
require 'promise'
require 'json'
require 'time'

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

    def insert(table, hsh)
        $controller.rpc('insert', table, hsh)
    end

    def update(table, id, hsh)
        $controller.rpc('update', table, id, hsh)
    end

    def start(app)
        begin
            controller = self
            @ws = Browser::Socket.new 'ws://localhost:3000' do
            #@ws = Browser::Socket.new 'wss://localhost:7443' do
                on :open do |e|
                    if !controller.app_rendered
                        $document.ready do
                          React.render(React.create_element(app), `document.getElementById('container')`)
                          controller.app_rendered = true
                        end
                    end
                end
                on :message do |e|
                    begin
                        controller.notify JSON.parse(e.data)
                    rescue Exception => e
                        puts e.message
                        puts e.backtrace.inspect
                    end
                end
                on :close do |e|
                    puts 'close and reset'
                    after(5) {reset}
                end
            end            
        rescue Exception => e  
            puts e.message  
            puts e.backtrace.inspect 
            after(5) {reset}
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
            times = []
            kwargs.each_pair do |k, v|
                if v.instance_of? Time
                    times << k
                end
            end
            @ws.send({command: command, id: id, args: args, kwargs: kwargs, times: times}.to_json)
        end

        def notify msg
            data = msg['data'] || msg['result']
            if data.instance_of? String && msg['times'] && msg['times'][0] == 'result'
                data = Time.parse data
            elsif msg['times'] and data.respond_to?(:each_pair)
                data.each_pair do |k, v|
                    if msg['times'].include? k
                        data[k] = Time.parse v
                    end
                end
            end
            if msg['response'] == 'watch'
                handle_watch_data msg['id'], data
            elsif msg['response'] == 'rpc'
                handle_rpc_result msg['id'], data
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

        def clear
            @watch.each_value do |value|
                value[:who].clear
            end
            @promises = {}
            @watch = {}
        end

        def logout
            clear
        end

        def reset
            clear
            start nil
        end
end
