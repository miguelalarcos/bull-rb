$LOAD_PATH.unshift '..'
require 'eventmachine'
require 'json'
require 'time'
require 'bcrypt'
require 'lib/encode_times' #..
require 'lib/symbolize'    #..

module Bull
    class Controller
        def initialize(ws, conn)
            @ws = ws
            @conn = conn
            @watch = {}
            @user_id = nil
        end

        def notify(msg)
            msg = JSON.parse msg #, symbolize_names: true
            print '>', msg, "\n"
            command = msg['command']
            kwargs = symbolize_keys(msg['kwargs']) # Hash[msg['kwargs'].map { |k, v| [k.to_sym, v] }]
            resolve_times kwargs, msg['times']
            #if msg['times']
            #    kwargs.each do |k, v|
            #        if msg['times'].include? k.to_s
            #            kwargs[k] = Time.parse v
            #        end
            #    end
            #end
            if command.start_with? 'rpc_'
                handle_rpc command, msg['id'], *msg['args'], **kwargs
            elsif command.start_with? 'watch_'
                handle_watch command, msg['id'], *msg['args'], **kwargs
            elsif command == 'stop_watch'
                handle_stop_watch msg['id']
            end
        end

        def close
            @watch.each_value {|w| w.close}
        end

        private

            def user_exist? user
                $r.table('user').filter(user: user).count().em_run(@conn) do |count|
                    if count == 0
                        yield false
                    else
                        yield true
                    end
                end
            end

            def rpc_login user, password
              $r.table('user').filter(user: user).em_run(@conn) do |response|
                pass = response['password']
                pass = BCrypt::Password.new(pass)
                if pass == password
                    @user_id = user
                    yield true
                else
                    yield false
                end
              end
            end

            def rpc_logout
                close
                @user_id = nil
                true
            end

            def user_is_owner? doc
                doc['owner'] == @user_id
            end

            def user_roles
                $r.table('user').get(@user_id).run(@conn)['roles']
            end

            def user_role_in? doc
                doc['update_roles'].to_set.intersect?(user_roles.to_set)
            end

            def i_timestamp! doc
                doc['i_timestamp'] = Time.now
            end

            def u_timestamp! doc
                doc['u_timestamp'] = Time.now
            end

            def owner! doc
                doc['owner'] = @user_id
            end

            def rpc_insert(table, value:)
                new_val = value
                new_val.delete :i_timestamp
                new_val.delete :owner
                new_val.delete :id

                if !self.send('before_insert_'+table, new_val)
                    yield nil
                else
                    $r.table(table).insert(new_val).em_run(@conn){|ret| yield ret['generated_keys'][0]}
                end
            end

            def rpc_delete(table, id)
                $r.table(table).get(id).em_run(@conn) do |doc|
                    if !self.send('before_delete_'+table, doc)
                        yield 0
                    else
                        $r.table(table).get(id).delete.em_run(@conn){|ret| yield ret['deleted']}
                    end
                end
            end

            def rpc_update(table, id, value:)
                value.delete :u_timestamp
                value.delete :update_roles
                value.delete :i_timestamp
                value.delete :owner
                value.delete :id
                #old_val = $r.table(table).get(id).run(@conn)
                $r.table(table).get(id).em_run(@conn) do |old_val|
                    old_val = symbolize_keys old_val

                    merged = old_val.merge(value)
                    if !(old_val && self.send('before_update_'+table, old_val, value, merged))
                        yield 0
                    else
                        #$r.table(table).get(id).update(merged).run(@conn)['replaced']
                        $r.table(table).get(id).update(merged).em_run(@conn){|ret| yield ret['replaced']}
                    end
                end
            end

            def handle_watch command, id, *args, **kwargs
                if kwargs.empty?
                    w = self.send command, *args
                else
                    w = self.send command, *args, **kwargs
                end
                return if !w
                w = w.changes({include_initial: true})
                EventMachine.run do
                    @watch[id] = w.em_run(@conn) do |doc|
                        puts doc
                        ret = {}
                        ret[:response] = 'watch'
                        ret[:id] = id
                        ret[:data] = doc
                        ret[:times] = times doc
                        @ws.send ret.to_json
                    end
                end
            end

            def handle_stop_watch id
                @watch[id].close
                @watch.delete id
            end

            def handle_rpc command, id, *args, **kwargs
                aux = ['rpc_update', 'rpc_get_location', 'rpc_get_i18n', 'rpc_get_car', 'rpc_insert', 'rpc_delete']
                if aux.include?(command) and kwargs.empty?
                    self.send(command, *args){|ret| @ws.send({response: 'rpc', id: id, result: ret, times: times(ret)}.to_json)}
                elsif aux.include?(command)
                    self.send(command, *args, **kwargs){|ret| @ws.send({response: 'rpc', id: id, result: ret, times: times(ret)}.to_json)}
                else
                    if kwargs.empty?
                        ret = self.send command, *args
                    else
                        ret = self.send command, *args, **kwargs
                    end
                    @ws.send({response: 'rpc', id: id, result: ret, times: times(ret)}.to_json)
                end
            end

            def get table, id
                $r.table(table).get(id).em_run(@conn) {|doc| print doc; yield doc}
            end

=begin
            def watch_by_id table, id
                if table == 'user'
                    return nil
                end
                doc = $r.table(table).get(id).run(@conn)
                if self.class.method_defined? 'before_watch_by_id_'+table
                    if !self.send('before_watch_by_id_'+table, doc)
                        return nil
                    end
                end
                $r.table(table).get(id).changes({include_initial: true})
            end
=end
            def times ret
                if !ret.respond_to? :each_pair
                    if ret.instance_of? Time
                        ['result']
                    else
                        []
                    end
                else
                    encode_times ret, ''
                    #times_ = []
                    #ret.each_pair do |k, v|
                    #    if v.instance_of? Time
                    #        times_ << k
                    #    end
                    #end
                    #return times_
                end
            end
    end
end