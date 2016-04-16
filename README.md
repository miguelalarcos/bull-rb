Bull-rb
=======

Ruby full stack for real time web apps:
---------------------------------------

Ruby + Opal + React.rb + EventMachine + Rethinkdb


This is a Meteor like framework, but with Ruby language. (Other example is Volt.)

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

The serve will send to the client a *return message* in the first case and *data* messages for a watch request.
Behind the scenes: a ticket (integer) is sent with each request to the server and sent back to the client, so the client knows who
notify with the data received.

Forms:
------

The framework comes with a Form class:

```ruby
class MyForm < Form

    @@table = 'car'
    param :selected

    before_mount do
           get params.selected
    end

    def clear
        state.registration! ''
        state.color! ''
        state.wheels! nil
        state.date! nil
        state.id! nil
        d = {'x' => nil}
        state.nested! d
        state.auto! ''
    end

    def render
        ValidateCar.new.validate state
        div do
            div{state.id}
            span{'Registration'}
            #input(class: valid_class state.is_valid_registration, value: state.registration).on(:click) {|e| state.registration! e.target.value}
            StringInput(is_valid: state.is_valid_registration, change_attr: change_attr('registration'), value: state.registration)
            div(class: 'red'){'not valid registration'} if !state.is_valid_registration
            span{'Wheels'}
            IntegerInput(is_valid: state.is_valid_wheels, key: 'my_key', change_attr: change_attr('wheels'), value: state.wheels)
            span{'Color'}
            SelectInput(change_attr: change_attr('color'), value: state.color, options: ['red', 'blue'])
            span{'Date'}
            DateTimeInput(change_date: change_attr('date'), format: '%d-%m-%Y %H:%M', value: state.date, time: true)
            span{'Nested'}
            FloatInput(is_valid: state.is_valid_nested_x, key: 'my_key2', change_attr: change_attr('nested.x'), value: state.nested['x'])
            span{'Autocomplete'}
            AutocompleteInput(change_attr: change_attr('auto'), ref_: 'location', #set_validation: lambda{|v| puts v; state.is_valid_auto! v},
                              name: 'description', value: state.auto)
            button(type: :button) { 'save' }.on(:click) {save} if (state.is_valid && state.is_valid_auto)
            button(type: :button) { 'clear' }.on(:click) {clear}
        end        
    end
end
```

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

Several components can watch the rvar and set a value to it. For example a form is editing the document given by the rvar
car_selected, and a list component of cars can set the car_selected to another id when clicking in one car.

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
        watch_ params.selected
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

See client/ui.rb for more details.

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

Server side:
------------
* main.rb: you define the custom controller used in the server
* server.rb: it has the controller class for the server
* start.rb: entry point for the server application

This is an example of a custom Controller:

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

  def rpc_print_car id
    check id, String
    get('car', id) do |doc|
      if user_is_owner? doc
        t = $reports['car']
        yield t.render(doc)
      else
        yield ''
      end
    end
  end

  def rpc_add a, b
    check a, Integer
    check b, Integer
    @mutex.synchronize do
      a + b
    end
  end

  def rpc_get_location value
    check value, String
    if value == ''
      yield []
    else
      ret = []
      docs_with_count($r.table('location').filter{|doc| doc['description'].match("(?i).*"+value+".*")}) do |count, row|
        ret << row
        if ret.length == count
          yield ret
          #break
        end
      end
    end
  end

  def rpc_get_i18n id
    check id, String
    get('i18n', id) {|doc| yield doc}
  end

  def rpc_get_car id
  check id, String
    get('car', id){|doc| yield doc}
  end

  def watch_car id
    check id, String
    $r.table('car').get(id)
  end

  def watch_cars_of_color color
    check color, String
    $r.table('car').filter(color: color)
  end

  def before_update_car old_val, new_val, merged
    if !ValidateCar.new.validate merged
      return false
    end
    u_timestamp! merged
    user_role_in? old_val
  end

  def before_delete_car doc
    user_is_owner? doc
  end

  def before_insert_car doc
    if user_roles.include? 'writer' && ValidateCar.new.validate(doc)
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

class ValidateCar
  include Validate

  def initialize
    field 'registration' => String
    field 'color' => String
    field 'wheels' => Integer
    field 'date' => Time
    field 'auto' => String
    field 'nested' => Hash
    field 'nested.x' => Float
  end

  def is_valid_registration? (value, doc)
    if doc[:wheels] <= 4
      value.start_with? 'A'
    else
      value.start_with? 'B'
    end
  end
end
```

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
* logout
* start(app)

Controller server side:
* user_is_owner? doc -> boolean
* user_roles -> list of roles
* def user_role_in? doc -> user has a role that is included in doc\['update_roles']
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
