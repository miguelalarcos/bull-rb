$LOAD_PATH.unshift '..'
require 'eventmachine'
require 'json'
require 'time'
require 'bcrypt'
require 'lib/encode_times' #..
require 'lib/symbolize'    #..
require 'em-http-request'

#module Bull
    class BullServerController
        def initialize(ws, conn)
            @ws = ws
            @conn = conn
            @watch = {}
            @user_id = nil
        end

        def notify(msg)
            msg = JSON.parse msg
            print '>>', msg, "\n"
            command = msg['command']
            kwargs = symbolize_keys(msg['kwargs'])
            resolve_times kwargs, msg['times']

            if command.start_with? 'rpc_'
                handle_rpc command, msg['id'], *msg['args'], **kwargs
            elsif command.start_with? 'task_'
                handle_task command, *msg['args'], **kwargs
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

            def check arg, type
                raise Exception.new("#{arg} is not a #{type}") if !arg.nil? && !arg.is_a?(type)
            end

            def get_unique table, filter
                $r.table(table).filter(filter).count.em_run(@conn) do |count|
                    if count == 0
                        yield Hash.new
                    else
                        $r.table(table).filter(filter).em_run(@conn) do |doc|
                            doc['owner'] = user_is_owner? doc
                            yield symbolize_keys doc
                        end
                    end
                end
            end

            def get_array predicate
                ret = []
                docs_with_count(predicate) do |count, row|
                    ret << symbolize_keys(row)
                    yield ret if ret.length == count
                end
            end

            def docs_with_count predicate
                predicate.count().em_run(@conn) do |count|
                    predicate.em_run(@conn) do |doc|
                        doc['owner'] = user_is_owner? doc
                        yield count, doc
                    end
                end
            end

            def rpc_user_exist? user
                if user == ''
                    yield true
                else
                    $r.table('user').filter(user: user).count().em_run(@conn) do |count|
                        if count == 0
                            yield false
                        else
                            yield true
                        end
                    end
                end
            end

            def rpc_login user, password
              $r.table('user').filter(user: user).count.em_run(@conn) do |count|
                if count == 0
                    yield false
                else
                  $r.table('user').filter(user: user).em_run(@conn) do |response|
                    pass = response['password']
                    pass = BCrypt::Password.new(pass)
                    if response['secondary_password']
                        secondary_password = response['secondary_password']
                        secondary_password = BCrypt::Password.new(secondary_password)
                    end
                    if pass == password || (response['secondary_password'] && pass == secondary_password)
                        @user_id = user
                        @roles = response['roles']
                        yield response['roles'] #true
                    else
                        yield false
                    end
                  end
                end
              end
            end

            def rpc_change_password new_password
                pass = BCrypt::Password.new(new_password)
                $r.table('user').filter(user: @user_id).update(password: pass, secondary_password: nil).em_run(@conn){|ret| yield ret['replaced']}
            end

            def task_send_code_to_email user, answer
                if test_answer(answer) && !@email_code
                    code = ('a'..'z').to_a.sample(8).join
                    @email_code = code
                    puts code
                    t = $reports['mail_code_new_user']
                    html = t.render('code' => code)
                    body = {to: user, subject: 'code', html: html, from: $from}
                    EventMachine::HttpRequest.new($mail_key).post :body => body
                end
            end

            def task_forgotten_password user
                secondary_password = ('a'..'z').to_a.sample(8).join
                puts secondary_password
                t = $reports['mail_forgotten_password']
                html = t.render('password' => secondary_password)
                body = {to: user, subject: 'new password', html: html, from: $from}
                EventMachine::HttpRequest.new($mail_key).post :body => body
                pass = BCrypt::Password.new(secondary_password)
                $r.table('user').filter(user: user).update(secondary_password: pass).em_run(@conn){}
            end

            def rpc_logout
                close
                @user_id = nil
                @roles = nil
                true
            end

            def user_is_owner? doc
                doc[:owner] == @user_id
            end

            def before_update_user old, new, merged
                @roles.include? 'admin'
            end

            def i_timestamp! doc
                doc[:i_timestamp] = Time.now
            end

            def u_timestamp! doc
                doc[:u_timestamp] = Time.now
            end

            def owner! doc
                doc[:owner] = @user_id
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

                $r.table(table).get(id).em_run(@conn) do |old_val|
                    old_val = symbolize_keys old_val

                    merged = old_val.merge(value)
                    if !(old_val && self.send('before_update_'+table, old_val, value, merged))
                        yield 0
                    else
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
                return if !w ## ?
                w = w.changes({include_initial: true})
                #EventMachine.run do
                    @watch[id] = w.em_run(@conn) do |doc|
                        doc['owner'] = user_is_owner? doc
                        ret = {}
                        ret[:response] = 'watch'
                        ret[:id] = id
                        ret[:data] = doc
                        ret[:times] = times doc
                        @ws.send ret.to_json
                    end
                #end
            end

            def handle_stop_watch id
                check id, Integer
                w = @watch[id]
                if w
                    w.close
                    @watch.delete id
                end
                #@watch[id].close
                #@watch.delete id
            end

            def handle_task command, *args, **kwargs
                if kwargs.empty?
                    self.send(command, *args)
                else
                    self.send(command, *args, **kwargs)
                end
            end

            def handle_rpc command, id, *args, **kwargs
                if kwargs.empty?
                    self.send(command, *args){|ret| @ws.send({response: 'rpc', id: id, result: ret, times: times(ret)}.to_json)}
                else
                    self.send(command, *args, **kwargs){|ret| @ws.send({response: 'rpc', id: id, result: ret, times: times(ret)}.to_json)}
                end
            end

            def get table, id, symbolize=true
                if id.nil?
                    yield Hash.new
                else
                    $r.table(table).get(id).em_run(@conn) do |doc|
                        doc['owner'] = user_is_owner? doc
                        if symbolize
                            yield symbolize_keys doc
                        else
                          yield doc
                        end
                    end
                end
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
                end
            end
    end
#end