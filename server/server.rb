require 'eventmachine'
require 'json'
require 'time'

class Controller
    def initialize(ws, conn)
        @ws = ws        
        @conn = conn
        @watch = {}
        @user_id = nil
    end

    def notify(msg)
        msg = JSON.parse msg #, symbolize_names: true
        command = msg['command']
        kwargs = Hash[msg['kwargs'].map { |k, v| [k.to_sym, v] }]
        if msg['times']
            kwargs.each do |k, v|
                if msg['times'].include? k
                    kwargs[k] = Time.parse v
                end
            end
        end
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

        def rpc_login! user
          @user_id = user
          true
        end

        def user_is_owner? doc
            doc['owner'] == @user_id
        end

        def user_roles
            $r.table('user').get(@user_id).run(@conn)['roles']
        end

        def user_role_in? doc
            doc["update_roles"].to_set.intersect?(user_roles.to_set)
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
            doc = $r.table(table).get(id).run(@conn)
            puts '==================================================', table, id, doc
            if self.class.method_defined? 'before_get_'+table
                if !self.send('before_get_'+table, doc)
                    return nil
                end
            end
            doc
        end

        def rpc_insert table, new_val
            new_val.delete 'i_timestamp'
            new_val.delete 'owner'
            new_val.delete 'id'
            if self.class.method_defined? 'before_insert_'+table
                if !self.send('before_insert_'+table, new_val)
                    return nil
                end
            end
            $r.table(table).insert(new_val).run(@conn)[:generated_keys][0]
        end        

        def rpc_update table, id, new_val
            new_val.delete 'u_timestamp'
            if self.class.method_defined? 'before_update_'+table
                old_val = $r.table(table).get(id).run(@conn)
                if !(old_val && self.send('before_update_'+table, old_val, new_val))
                    return 0
                end
            end
            new_val.delete 'update_roles'
            new_val.delete 'i_timestamp'
            new_val.delete 'owner'
            new_val.delete 'id'
            $r.table(table).get(id).update(new_val).run(@conn)[:replaced]            
        end

        def handle_watch command, id, *args, **kwargs
            puts '=>', command, args, kwargs
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
            #try
            if kwargs.empty?
                ret = self.send command, *args
            else
                ret = self.send command, *args, **kwargs
            end
            @ws.send({response: 'rpc', id: id, result: ret, times: times(ret)}.to_json)
        end

        def watch_by_id table, id
            doc = $r.table(table).get(id).run(@conn)    
            if self.class.method_defined? 'before_watch_by_id_'+table
                if !self.send('before_watch_by_id_'+table, doc)
                    return nil
                end
            end
            $r.table(table).get(id).changes({include_initial: true})    
        end

        def times kwargs
            times_ = []
            kwargs.each_pair do |k, v|
                if v.instance_of? Time
                    times_ << k
                end
            end
          times_
        end
end

