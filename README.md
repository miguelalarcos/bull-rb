Bull-rb
=======

Ruby full stack for real time web apps:
---------------------------------------

[Ruby](https://www.ruby-lang.org/es/) + [Opal](http://opalrb.org/) + [React.rb](http://reactrb.org/) + [EventMachine](https://github.com/eventmachine/eventmachine) + [Rethinkdb](https://www.rethinkdb.com/)

This is a [Meteor](https://www.meteor.com/) like framework, but with Ruby language. (Other example is [Volt](http://voltframework.com/))

There's also a [blog](http://codrspace.com/miguelalarcos/) where I'm going to post about *Bull-rb*

From client side you can ask the server in three ways:

* rpc (returns a promise)

    examples:
    $controller.rpc('add', 3, 4).then do |response| ... end

    other example:
    $controller.rpc('login', user, password)

* task

    like *rpc* but doesn't return value

* watch

    example: $controller.watch('cars_of_color', 'red') do ... end

    the server will notify the client if:
    * a new red car is created
    * a red car changes
    * a red car changes the color

The framework comes with a Form class:

```ruby
class OrderForm < Form
...
end
```

The framework comes with a DisplayDoc class:

```ruby
class OrderDoc < DisplayDoc
...
end
```

And it comes with a DisplayList class:

```
class OrderList < DisplayList
...
end
```

We are going to see those features.

RVar
----
You can have reactive vars, and use like this:

```ruby
v = RVar.new 0

reactive(v) do  # whenever the value changes, the block is executed
    puts v.value
end

v.value = 8
# 8
```

Other example, in App before_mount:

```ruby
@language = RVar.new 'es'

reactive(@language) do
    $controller.rpc('get', 'i18n', @language.value).then do|response|
        state.i18n_map! response
    end
end
```
Every time language is set (language.value = 'es') the `$controller.rpc('get',...` is rerun.

Rvars are useful when you are editing a form and you click in another form of a list to edit this one. The form would be:

```ruby
class OrderForm < Form
    @@table = 'order'
    param :order_code #this is a RVar
    param :order_exists

    before_mount do
        get params.order_code  # get does reactive inside. If we set order_code in another place, the code inside get will be rerun_
    end

    def clear
        state.code! nil
        state.description! ''
        state.client_code! nil
        state.date! nil
    end

    def render
        ValidateOrder.new.validate state
        div do
            div{'Order form'}
            div{state.code}
            button{'new order'}.on(:click) do
                $controller.rpc('get_ticket').then do |code|
                    clear
                    state.code! code
                    params.order_exists.call false
                end
            end
            hr
            ClientSearch(on_select: change_attr('client_code'))
            hr
            div('Date:')
            DateTimeInput(change_attr: change_attr('date'), format: '%d-%m-%Y %H:%M')
            div{'Description:'}
            StringInput(value: state.description, change_attr: change_attr('description'))
            button{'save'}.on(:click) do
                save
                params.order_exists.call true
            end if state.valid
        end
    end
end
```

The canonical way of writing a custom component:
------------------------------------------------

```ruby
class DisplayCar < React::Component::Base
    @@table = 'car'
    param :selected

    before_mount do
        @predicate_id = nil
        @rvs = reactive(params.selected) do
            value = params.selected.value
            clear
            $controller.stop_watch(@predicate_id) if @predicate_id
            @predicate_id = $controller.watch('by_id', @@table, value) do |data|
                data['new_val'].each {|k, v| state.__send__(k+'!', v)}
            end
        end
    end

    def clear
        state.registration! ''
        state.color! ''
    end

    def render
        div do
            {state.registration + ', color: ' + state.color}
        end
    end

    before_unmount do
      $controller.stop_watch @predicate_id if @predicate_id
      @rvs.each_pair {|k, v| v.remove k}
    end
end
```

And this is a simplified way of doing the same:

```ruby
class DisplayCar < DisplayDoc
    @@table = 'car'
    param :selected

    before_mount do
        watch_ params.selected.value, [params.selected]
    end

    def clear
        state.registration! ''
        state.color! ''
    end

    def render
        div do
            {state.registration + ' color: ' + state.color}
        end
    end
end
```

Lets see a component List like:

```ruby
class OrderLines < DisplayList
    param :line_selected # this is a RVar
    param :order_code    # this is a RVar

    before_mount do
        watch_ 'lines_of_order', params.order_code.value, [params.order_code]
    end

    def render
        total = state.docs.inject(0){|sum, doc| sum + doc['price']}
        div do
            div{'Order lines'}
            state.docs.each do |doc|
                div(key: doc['id']) do
                    tr do
                        td{doc['product']}
                        td{doc['quantity']}
                        td{doc['price']}
                        td{'Edit'}.on(:click) do
                            params.line_selected.value = doc['id']
                        end
                    end
                end
            end
            span{"Total: #{total} €"}
        end
    end
end
```

Files
-----
Client side:

* client.rb: it has the controller class for the client
* i18n.rb: module for i18n
* index.html: this is the file sent to the browser by the http server
* main.rb: the entry point for Opal. You must define here the global $controller
* Rakefile: to make the build.js and build.css
* reactive_var.rb: here you've got the implementation for reactive vars. Please note that this reactive var does not work
  with the render method of the react.rb components. This works with the provided reactive function.
* ui.rb: here you've got all the React components of the client application.
* ui_core.rb: useful ui components like Form, PasswordInput, ...
* bcaptcha.rb: create user ui with textcaptcha or netcaptcha

Server side:
------------
* main.rb: you define the custom controller used in the server
* server.rb: it has the controller class for the server
* start.rb: entry point for the server application
* bcaptcha: functions to provide captcha service

Gems:
-----
* bull-autocomplete
* bull-date-time-picker

This is an example of a custom server Controller:

```ruby
require './server'
require 'em-synchrony'
require '../validation/validation'
require './bcaptcha'
require 'liquid'

class MyController < Bull::Controller

  include NetCaptcha

  def initialize ws, conn
    super ws, conn
    @mutex = EM::Synchrony::Thread::Mutex.new
  end

  def rpc_print_order id
    check id, String # it raises an exception if id is not a String
    get('order', id) do |doc| # to be strict, this should be a join between *order* and *lines* tables
      if user_is_owner? doc
        t = $reports['order']
        yield t.render(doc)
      else
        yield ''
      end
    end
  end

    def rpc_get_ticket
      @mutex.synchronize do
        $r.table('ticket').get('0').em_run(@conn) do|doc|
          $r.table('ticket').get('0').update({value: doc['value'] + 1}).em_run(@conn) do
            yield doc['value']
          end
        end
      end
    end

    def rpc_get_clients code, surname
      check code, Integer
      check surname, String
      get_array(
          $r.table('client').filter do |cli|
            cli['code'] == code | cli['surname'].match("(?i).*"+surname+".*")
          end
      ) {|docs| yield docs}
    end

  def rpc_get_i18n id
    check id, String
    get('i18n', id) {|doc| yield doc}
  end

  def watch_orders code, client_code, date
    check code, Integer
    check client_code, Integer
    check date, Time
    $r.table('order').filter do |v|
      v['code'] == code | (v['client_code'] == client_code & (v['date'] == date))
    end
  end

  def watch_lines_of_order code
    check code, Integer
    $r.table('line').filter(order_code: code)
  end

  def before_update_order old_val, new_val, merged
    if !ValidateOrder.new.validate merged
      return false
    end
    u_timestamp! merged
    user_role_in? old_val
  end

  def before_delete_order doc
    user_is_owner? doc
  end

  def before_insert_order doc
    if user_roles.include? 'writer' && ValidateOrder.new.validate(doc)
      i_timestamp! doc
      owner! doc
      true
    else
      false
    end
  end
end
```

Both sides:
-----------
* validation.rb: here is defined the module Validate. You use it the next way:

```ruby
require_relative 'validation_core'

class ValidateOrder
  include Validate

  def initialize
    field 'code' => String
    field 'description' => String
    field 'client_code_' => Integer
    field 'date' => Time
  end

  def is_valid_description? (value, doc)
    value.start_with? 'Description: '
  end
end
```

You can have nested fields: `field 'nested.power' => Float`

Instructions to install and execute:
------------------------------------
* You have to install Ruby and Rethinkdb.
* Clone the repository: git clone https://github.com/miguelalarcos/bull-rb.git
* Gemfile in client folder
* Gemfile in server folder
* Console in client folder:

    *$ rake css
    *$ rake development

* Console in client folder:

    * $ python -m SimpleHTTPServer

* Console in root folder:

    *$ ruby setup_data_base.rb (pending of create the rb file)
    *$ rethinkdb    

* Console in server folder:

    * $ ruby start.rb

* Open browser in localhost:8000

API
---
Controller client side:
* watch(name, *args, &block) -> id
* stop_watch(id)
* rpc(command, \*args) -> promise

  you can send Time objects, but you have to use keyword arguments: rpc('date middle', date_ini: Time.now, date_end: Time.now + 24*60*60)
  Behind the scenes: with the message sent to the server, there is an array *times* with the attrs that are Time instances. This is the
  way I construct Times in the other side.

* insert(table, hsh) -> promise
* update(table, id, hsh) -> promise
* delete(table, id)
* logout
* start(app)

Controller server side:
* user_is_owner? doc -> boolean
* user_roles -> list of roles
* user_role_in? doc -> user has a role that is included in doc\['update_roles']
* i_timestamp! doc # sets the inserted timestamp
* u_timestamp! doc # sets the updated timestamp
* owner! doc # sets the user_id as owner in the doc

TODO
----
* change the name of files. For example rename client.rb for client_controller.rb
  ui.core.rb --> ui_utils.rb
  ui.rb --> app_ui.rb
  server.rb --> server_controller.rb
* login and create user API controller client side.
* lots of things
* Do you like the code name of the project? --> Bull

Help
----
Please contact me if you would like to contribute to the project. All opinions are welcome.
