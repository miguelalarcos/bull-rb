$LOAD_PATH.unshift '..'
require 'eventmachine'
require 'json'
require 'time'
require 'bcrypt'
require 'lib/encode_times' #..
require 'lib/symbolize'    #..
require 'em-http-request'
require 'logger'
require 'fiber'
#require 'liquid'
require './mreport'

class EMLogger < Logger
    def initialize(file, count: 1, size: 1024000, level: Logger::DEBUG)
        super file, count, size
        @level = level
    end

    def error msg
        #puts 'error:', msg
        EventMachine.defer(proc {super msg})
    end

    def info msg
        #puts 'info:', msg
        EventMachine.defer(proc {super msg})
    end

    def debug msg
        #puts 'debug:', msg
        EventMachine.defer(proc {super msg})
    end

    def warn msg
        #puts 'warn:', msg
        EventMachine.defer(proc {super msg})
    end
end

module Logging
    def logger
        Logging.logger
    end

    def self.logger
        @logger ||= EMLogger.new('bull-rb.log', count: 10, size: 1024000, level: Logger::DEBUG)
    end

    def stdout_logger
        Logging.stdout_logger
    end

    def self.stdout_logger
        @stdout_logger ||= EMLogger.new(STDOUT, level: Logger::DEBUG)
    end
end

#module Bull
class BullServerController

    include Logging
    include MReport

    def initialize(ws, conn)
        @ws = ws
        @conn = conn
        @watch = {}
        @user_id = nil

        #@reports = {}
        #Dir.glob(File.join('reports' , '*.html')).each do |file|
        #    html = File.read(file)
        #    @reports[File.basename(file, '.html')] = Liquid::Template.parse(html)
        #end
        #puts 'reports loaded'
    end

    def notify(msg)
        msg = JSON.parse msg
        logger.info msg
        stdout_logger.info msg
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
            count = rsync $r.table(table).filter(filter).count
            if count == 0
                return nil #Hash.new
            else
              docs = rmsync $r.table(table).filter(filter)
              doc = docs[0]
              doc['owner'] = owner? doc
              return symbolize_keys doc
            end
        end

        def get_array predicate
            ret = []
            docs_with_count(predicate) do |count, row|
                if count == 0
                    yield []
                else
                    ret << symbolize_keys(row)
                    yield ret if ret.length == count
                end
            end
        end

        def docs_with_count predicate
            predicate.count.em_run(@conn) do |count|
                if count == 0
                    yield 0, {}
                else
                    predicate.em_run(@conn) do |doc|
                        doc['owner'] = owner? doc
                        yield count, doc
                    end
                end
                #predicate.em_run(@conn) do |doc|
                #    doc['owner'] = owner? doc
                #    print 'yield', count, doc
                #    puts
                #    yield count, doc
                #end
            end
        end

        def rpc_user_exist? user
            check user, String
            if user == ''
                return true # false
            else
                count = rsync $r.table('user').filter(user: user).count()
                if count == 0
                    return false
                else
                    return true
                end
                #$r.table('user').filter(user: user).count().em_run(@conn) do |count|
                #    if count == 0
                #        yield false
                #    else
                #        yield true
                #    end
                #end
            end
        end

        def rpc_login user, password
            check user, String
            check password, String
            count = rsync $r.table('user').filter(user: user).count
            if count == 0
                return false
            else
                response = rsync $r.table('user').filter(user: user)
                pass = response['password']
                pass = BCrypt::Password.new(pass)
                if response['secondary_password']
                    secondary_password = response['secondary_password']
                    secondary_password = BCrypt::Password.new(secondary_password)
                end
                if pass == password || (response['secondary_password'] && pass == secondary_password)
                    @user_id = user
                    @roles = response['roles']
                    return response['roles']
                else
                    return false
                end
            end
        end

        def rpc_login_old user, password
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
            check new_password, String
            pass = BCrypt::Password.new(new_password)
            ret = rsync $r.table('user').filter(user: @user_id).update(password: pass, secondary_password: nil)
            ret['replaced']
            #$r.table('user').filter(user: @user_id).update(password: pass, secondary_password: nil).em_run(@conn){|ret| yield ret['replaced']}
        end

        def task_send_code_to_email user, answer
            check user, String
            check answer, String
            if test_answer(answer) && !@email_code
                code = ('a'..'z').to_a.sample(8).join
                @email_code = code
                puts code
                t = reports['mail_code_new_user']
                html = t.render('code' => code)
                body = {to: user, subject: 'code', html: html, from: $from}
                EventMachine::HttpRequest.new($mail_key).post :body => body
            end
        end

        def task_forgotten_password user
            check user, String
            secondary_password = ('a'..'z').to_a.sample(8).join
            puts secondary_password
            t = reports['mail_forgotten_password']
            html = t.render('password' => secondary_password)
            body = {to: user, subject: 'new password', html: html, from: $from}
            EventMachine::HttpRequest.new($mail_key).post :body => body
            pass = BCrypt::Password.new(secondary_password)
            #$r.table('user').filter(user: user).update(secondary_password: pass).em_run(@conn){}
            rsync $r.table('user').filter(user: user).update(secondary_password: pass)
        end

        def rpc_logout
            close
            @user_id = nil
            @roles = nil
            true
        end

        #def user_is_owner? doc
        #    doc[:owner] == @user_id
        #end

        def owner? doc
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
            check table, String
            new_val = value
            new_val.delete :i_timestamp
            new_val.delete :owner
            new_val.delete :id

            if !self.send('before_insert_'+table, new_val)
                nil
            else
                ret = rsync $r.table(table).insert(new_val)
                ret['generated_keys'][0]
            end
        end

        def rpc_delete(table, id)
            check table, String
            doc = rsync $r.table(table).get(id)
            if doc.nil? || !respond_to?('before_delete_'+table) || !self.send('before_delete_'+table, doc)
                0
            else
                ret = rsync $r.table(table).get(id).delete
                ret['deleted']
            end
            #$r.table(table).get(id).em_run(@conn) do |doc|
                #begin
            #        if doc.nil? || !respond_to?('before_delete_'+table) || !self.send('before_delete_'+table, doc)
            #            yield 0
            #        else
            #            $r.table(table).get(id).delete.em_run(@conn){|ret| yield ret['deleted']}
            #        end
                #rescue
                #    yield 0
                #end
            #end
        end

        def rsync pred
            helper = Fiber.new do |parent|
                pred.em_run(@conn) do |doc|
                    parent.transfer doc
                end
            end
            helper.transfer Fiber.current
        end

        def rmsync pred
            helper = Fiber.new do |parent|
                get_array(pred){|docs| parent.transfer docs}
            end
            helper.transfer Fiber.current
        end

        def rpc_update(table, id, value:)
            check table, String
            check id, String
            value.delete :u_timestamp
            value.delete :update_roles
            value.delete :i_timestamp
            value.delete :owner
            value.delete :id

            old_doc = rsync $r.table(table).get(id)
            if old_doc.nil? || !respond_to?('before_update_'+table)
                return 0
            end
            old_doc = symbolize_keys old_doc
            merged = old_doc.merge(value)
            if !self.send('before_update_'+table, old_doc, value, merged)
                0
            else
                response = rsync $r.table(table).get(id).update(merged)
                response['replaced']
            end
        end

        def rpc_update_old(table, id, value:)
            value.delete :u_timestamp
            value.delete :update_roles
            value.delete :i_timestamp
            value.delete :owner
            value.delete :id

            $r.table(table).get(id).em_run(@conn) do |old_val|
                #begin
                    if old_val.nil? || !respond_to?('before_update_'+table)
                        yield 0
                    else
                        old_val = symbolize_keys old_val
                        merged = old_val.merge(value)
                        if !(old_val && self.send('before_update_'+table, old_val, value, merged))
                            yield 0
                        else
                            $r.table(table).get(id).update(merged).em_run(@conn){|ret| yield ret['replaced']}
                        end
                    end
                #rescue
                #    yield 0
                #end
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
                doc['owner'] = owner? doc
                ret = {}
                ret[:response] = 'watch'
                ret[:id] = id
                ret[:data] = doc
                ret[:times] = times doc
                #begin
                @ws.send ret.to_json
                #rescue
                #end
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
            helper = Fiber.new do
                begin
                    if kwargs.empty?
                        self.send(command, *args)
                    else
                        self.send(command, *args, **kwargs)
                    end
                rescue Exception => e
                    logger.debug e
                    stdout_logger.debug e
                end
            end
            helper.transfer
        end

        def handle_rpc command, id, *args, **kwargs
            helper = Fiber.new do
              begin
                if kwargs.empty?
                    v = self.send(command, *args)
                else
                    v = self.send(command, *args, **kwargs)
                end
                @ws.send({response: 'rpc', id: id, result: v, times: times(v)}.to_json)
              rescue Exception => e
                  logger.debug e
                  stdout_logger.debug e
              end
            end
            helper.transfer
        end

        def handle_rpc_old command, id, *args, **kwargs
            if kwargs.empty?
                self.send(command, *args){|ret| @ws.send({response: 'rpc', id: id, result: ret, times: times(ret)}.to_json)}
            else
                self.send(command, *args, **kwargs){|ret| @ws.send({response: 'rpc', id: id, result: ret, times: times(ret)}.to_json)}
            end
        end

        def get table, id, symbolize=true
            if id.nil?
                return nil # Hash.new # nil
            else
                doc = rsync $r.table(table).get(id)
                doc['owner'] = owner? doc
                if symbolize
                    return symbolize_keys doc
                else
                    return doc
                end
                #$r.table(table).get(id).em_run(@conn) do |doc|
                #    doc['owner'] = owner? doc
                #    if symbolize
                #        yield symbolize_keys doc
                #    else
                #      yield doc
                #    end
                #end
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