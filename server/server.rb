require 'eventmachine'
require 'json'
require 'time'
require 'bcrypt'
require '../lib/encode_times'
require '../lib/symbolize'

module Bull
    class Controller
        def initialize(ws, conn)
            @ws = ws
            @conn = conn
            @watch = {}
            @user_id = nil
        end

        def notify(msg)
            puts msg
            msg = JSON.parse msg #, symbolize_names: true
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

            def rpc_login user, password
              #pass = BCrypt::Password.create('secret')
              pass = $r.table('user').filter(user: user).run(@conn).to_a[0]['password']
              pass = BCrypt::Password.new(pass)
              if pass == password
                @user_id = user
                true
              else
                false
              end
            end

            def rpc_logout
                close
                @user_id = nil
                true
            end

            def rpc_create_user user, password
                # check if the user exists
                password = BCrypt::Password.create(password)
                $r.table('user').insert(user: user, password: password, roles: []).run(@conn)['generated_keys'][0]
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

            def rpc_get table, id
                if table == 'user'
                    return {}
                end
                doc = $r.table(table).get(id).run(@conn)
                if self.class.method_defined? 'before_get_'+table
                    if !self.send('before_get_'+table, doc)
                        return nil
                    end
                end
                doc
            end

            def rpc_insert(table, value:)
                new_val = value
                if table == 'user'
                    return nil
                end
                new_val.delete 'i_timestamp'
                new_val.delete 'owner'
                new_val.delete 'id'
                if self.class.method_defined? 'before_insert_'+table
                    if !self.send('before_insert_'+table, new_val)
                        return nil
                    end
                end
                $r.table(table).insert(new_val).run(@conn)['generated_keys'][0]
            end

            def rpc_update(table, id, value:)
                if table == 'user'
                    return 0
                end
                value.delete 'u_timestamp'
                old_val = $r.table(table).get(id).run(@conn)
                #old_val = Hash[old_val.map { |k, v| [k.to_sym, v] }]
                old_val = symbolize_keys old_val
                if self.class.method_defined? 'before_update_'+table
                    if !(old_val && self.send('before_update_'+table, old_val, value))
                        return 0
                    end
                end
                value.delete 'update_roles'
                value.delete 'i_timestamp'
                value.delete 'owner'
                value.delete 'id'
                $r.table(table).get(id).update(value).run(@conn)[:replaced]
            end

            def handle_watch command, id, *args, **kwargs
                if kwargs.empty?
                    w = self.send command, *args
                else
                    w = self.send command, *args, **kwargs
                end
                return if !w
                EventMachine.run do
                    @watch[id] = w.em_run(@conn) do |doc|
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
                if kwargs.empty?
                    ret = self.send command, *args
                else
                    ret = self.send command, *args, **kwargs
                end
                @ws.send({response: 'rpc', id: id, result: ret, times: times(ret)}.to_json)
            end

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