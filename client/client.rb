#require 'opal'
require 'browser'
require 'browser/socket'
require 'browser/delay'
require 'promise'
require 'json'
require 'time'
require 'lib/encode_times'
require 'reactive_var'

=begin
$connection = RVar.new 'disconnected'

reactive($connection) do
    if $connection.value == 'disconnected'
        $notifications.add ['error', 'disconnected', 1] if $notifications
    else
        $notifications.add ['ok', 'connected', 1] if $notifications
    end
end
=end

class BullClientController

    attr_accessor :app_rendered
    attr_accessor :ws
    attr_reader :connection
    @@ticket = 0

    def initialize
        @watch = {}
        @promises = {}
        @ws = nil
        @app_rendered = false

        @connection = RVar.new 'disconnected'
        reactive(@connection) do
            if @connection.value == 'disconnected'
                $notifications.add ['error', 'disconnected', 1] if $notifications
            else
                $notifications.add ['ok', 'connected', 1] if $notifications
            end
        end
    end

    def watch(name, *args, &block)
        id = get_ticket
        @watch[id] = {who: block, name: name, args: args}
        send('watch_' + name, id, *args)
        id
    end

    def task(name, *args)
        send 'task_' + name, -1, *args
    end

    def get_watch
        @watch
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
        prom = rpc('insert', table, value: hsh).then do |response|
            if response.nil?
                $notifications.add ['error', 'data not inserted', 0] if $notifications
            else
                $notifications.add ['ok', 'data inserted', 0] if $notifications
            end
            response
        end
        prom
    end

    def update(table, id, hsh)
        prom = rpc('update', table, id, value: hsh).then do |count|
            if count == 0
                $notifications.add ['error', 'data not updated', 0] if $notifications
            elsif count == 1
                $notifications.add ['ok', 'data updated', 0] if $notifications
            end
            count
        end
        prom
    end

    def delete(table, id)
        prom = rpc('delete', table, id).then do |count|
            if count == 0
                $notifications.add ['error', 'data not deleted', 0] if $notifications
            elsif count == 1
                $notifications.add ['ok', 'data deleted', 0] if $notifications
            end
            count
        end
        prom
    end

    def logout
        rpc('logout')
        clear
    end

    def notify msg
        msg = JSON.parse(msg)
        data = msg['data'] || msg['result']
        if data.instance_of?(String) && msg['times'] && msg['times'][0] == 'result'
            data = Time.parse data
        else
            resolve_times data, msg['times']
        end
        if msg['response'] == 'watch'
            handle_watch_data msg['id'], data
        elsif msg['response'] == 'rpc'
            handle_rpc_result msg['id'], data
        end
    end

    def start(app)
        begin
            controller = self
            url = 'ws://' + `document.location.hostname` + ':3000'
            @ws = Browser::Socket.new url do
            #@ws = Browser::Socket.new 'ws://localhost:3000' do
            #@ws = Browser::Socket.new 'wss://localhost:3000' do
                on :open do |e|
                    controller.connection.value = 'connected'
                    if !controller.get_watch.empty?
                        controller.get_watch.each do |id, value|
                            controller.send 'watch_' + value[:name], id, *value[:args]
                        end
                    end
                    if !controller.app_rendered
                        $document.ready do
                          React.render(React.create_element(app), `document.getElementById('container')`)
                          controller.app_rendered = true
                        end
                    end
                    if $user_id
                        controller.rpc('login', $user_id, $password)
                    end
                end
                on :message do |e|
                    begin
                        controller.notify e.data #JSON.parse(e.data)
                    rescue Exception => e
                        print e.message
                        print e.backtrace.inspect
                    end
                end
                on :close do |e|
                    controller.connection.value = 'disconnected'
                    $window.after(5) {controller.reset}
                end
            end            
        rescue Exception => e  
            print e.message
            print e.backtrace.inspect
            $window.after(5) {reset}
        end
    end

    private

        def get_ticket
            id = @@ticket
            @@ticket += 1
            id
        end

        def send(command, id, *args, **kwargs)
            times = encode_times(kwargs)
            msg = {command: command, id: id, args: args, kwargs: kwargs, times: times}.to_json
            @ws.send(msg)
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
                value[:who].call nil
            end
            @promises = {}
            #@watch = {}
        end

        def reset
            clear
            start nil
        end
end
