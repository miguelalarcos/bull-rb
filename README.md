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

```ruby
class OrderList < DisplayList
...
end
```

We are going to see those features in a moment.

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
  before_mount do
    @language = RVar.new 'en'
    reactive(@language) do
      $controller.rpc('get_unique_i18n', @language.value).then do|response|
        state.i18n_map! response
      end
    end
```
Every time language is set (language.value = 'es') the `$controller.rpc('get...',...` is rerun.

Rvars are useful when you are editing a form and you click in an item of a list to edit this one.

i18n
----

This is an example of a i18n map:

```
'lang': 'en'
'map':
  'DOC_TEXT': 'The document with id %{id} has these values:'
  'THERE_ARE_APPLE':
    '0': 'There are no apples'
    '1': 'There is one apple'
    '2..': 'There are %{count} apples'
```
And you would use like this:

```ruby
context = {id: state.id}
div{i18n(params.i18n_map, 'DOC_TEXT')%context}
context = {count: 5}
div{i18n(params.i18n_map, 'THERE_ARE_APPLE', 5)%context}
```

Forms
-----

```ruby
class DemoForm < Form
  @@table = 'demo'
  @@constants = ['cte']
  param :selected
  param :cte

  before_mount do
    get params.selected
  end

  def clear
    state.id! nil
    state.string_a! ''
    state.password! ''
    state.integer_x! nil
    ...
  end

  def render
    ValidateDemo.new.validate state
    div do
      table do
        tr do
          td{'A string'}
          td{StringInput(valid: state.valid_string_a, dirty: state.dirty_string_a, placeholder: 'string',
                         value: state.string_a, on_change: change_attr('string_a'))}
          td(class: 'error'){'string must start with A'} if !state.valid_string_a
        end
        tr do
          td{'A password'}
          td{PasswordInput(placeholder: 'password', value: state.password, on_change: change_attr('password'))}
        end
        tr do
          td{'An integer'}
          td{IntegerCommaInput(valid: state.valid_integer_x, dirty: state.dirty_integer_x, placeholder: 'integer',
                          value: state.integer_x, on_change: change_attr('integer_x'))}
          td(class: 'error'){'integer must be > 10'} if !state.valid_integer_x
        end
        tr do
          td{'A nested float'}
          td{FloatCommaInput(key: 'float_y', valid: state.valid_nested_float_y_value, dirty: state.dirty_nested_float_y_value,
                        placeholder: 'nested float', value: state.nested_float_y[:value],
                        on_change: change_attr('nested_float_y.value'))}
          td(class: 'error'){'float must be negative'} if !state.valid_nested_float_y_value
        end
        ...
    FormButtons(save: lambda{save}, discard: lambda{discard}, valid: state.valid, dirty: state.dirty)
```

What happens if I click in an item of a list of forms to edit this one, and the form is dirty? Well, we don't want to lose the data.

```ruby
class DemoList < DisplayList
  param :selected
  param :show_modal

  include MNotification

  before_mount do
    watch_ 'demo_items', []
  end

  def render
    div do
      table do
        tr do
          th{'id'}
          th{'string_a'}
          th{'integer_x'}
          th{'nested_float_y.value'}
        end
        state.docs.each do |doc|
          tr(key: doc['id']) do
            td{doc['id']}
            td{doc['string_a']}
            td{format_integer doc['integer_x']}
            td(class: 'montserrat'){format_float_sup_money(doc['nested_float_y']['value'], '€')}
            td{a(href: '#'){'delete'}.on(:click){$controller.delete('demo', doc['id'])}}
            td do
              a(href: '#'){'select'}.on(:click) do
                begin
                  RVar.raise_if_dirty do
                    params.selected.value = doc['id']
                  end
                rescue
                  notify_error 'There are data not saved. Save or discard the data.', 1
                  params.show_modal.call
                end
              end
            end
          end
        end
      end
    end
  end
end
```

Also there's a *rgrouping* function when you want to group the changes of several Rvars:

```ruby
RVAr.rgrouping do
  var1.value = 5
  var2.value = 7
end
```
Then the blocks involved will be executed at the end of this block, and not at every RVar change.

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
                clear
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
Files
-----
Client side:

* client.rb: it has the controller class for the client
* i18n.rb: module for i18n
* index.html: this is the file sent to the browser by the http server
* main.rb: the entry point for Opal.
* Rakefile: to make the build.js and build.css
* reactive_var.rb: here you've got the implementation for reactive vars. Please note that this reactive var does not work
  with the render method of the react.rb components. This works with the provided reactive function.
* ui.rb: here you've got all the React components of the client application. Here goes the React component App.
* ui_core.rb: useful ui components like DisplayDoc, DisplayList, Form, StringInput, PasswordInput, MultiLineInput, IntegerInput, FloatInput and SelectInput.
* login.rb: login, create user ui with textcaptcha or netcaptcha

Server side:
------------
* main.rb: you define the custom controller (AppController)
* server.rb: it has the controller class for the server
* start.rb: entry point for the server application
* bcaptcha: functions to provide captcha service

This is an example of a custom server Controller:

```ruby
require './server'
require './bcaptcha'
require '../validation/validation_demo'

class AppController < BullServerController

  include NetCaptcha

  def initialize ws, conn
      super ws, conn
      #@mutex = EM::Synchrony::Thread::Mutex.new # I used it in *rpc_get_ticket* but I prefer the current implementation
  end

  def rpc_get_ticket
    #@mutex.synchronize do
    doc = rsync $r.table('ticket').get('0').update(:return_changes => true) do |doc|
      :value => doc['value'] + 1
    end
    doc['changes'][0]['new_val']['value']
  end

  def rpc_report_demo id
    check id, String
    doc = get('demo', id, symbolize=false)
    t = reports['demo']
    t.render(doc)
  end

  def rpc_location loc
    check loc, String
    pred = $r.table('location').filter do |doc|
      doc['name'].match("(?i).*" + loc + ".*")
    end
    docs = rmsync pred
    docs.collect{|x| x[:name]}
  end

  def before_insert_demo doc
    ValidateDemo.new.validate doc
  end

  def before_update_demo old, new, merged
    ValidateDemo.new.validate merged
  end

  def before_delete_demo id
    true
  end

  def rpc_get_unique_i18n(lang)
    check lang, String
    get_unique('i18n', {lang: lang}) #{|doc| yield doc}
  end

  def rpc_get_demo id
    check id, String
    get('demo', id) #{|doc| yield doc}
  end

  def watch_demo id
    check id, String
    if !id.nil?
      $r.table('demo').get(id)
    end
  end

  def watch_demo_items
    $r.table('demo')
  end

end
```

Both sides:
-----------
* validation.rb: here is defined the module Validate. You use it the next way:

```ruby
require_relative 'validation_core'

class ValidateDemo
  include Validate

  def initialize
    field 'string_a' => String
    field 'password' => String
    field 'integer_x' => Integer
    field 'nested_float_y.value' => Numeric #Float
    field 'observations' => String
  end

  def valid_string_a? (value, doc)
    value.start_with? 'A'
  end

  def valid_integer_x? (value, doc)
    value > 10
  end

  def valid_nested_float_y_value?(value, doc)
    value < 0.0
  end

end
```

You can have nested fields: `field 'nested.power' => Numeric`

Instructions to install and execute:
------------------------------------
* You have to install Ruby and Rethinkdb.
* Clone the repository: git clone https://github.com/miguelalarcos/bull-rb.git
* git checkout rsync
* Gemfile in client folder
* Gemfile in server folder
* Console in client folder:

    *$ rake css
    *$ rake development

* Console in client/http folder:

    * $ ruby http_server.rb (you can change the code to execute with ssl. You then execute `rvmsudo ruby http_server.rb`)
    (I will write the code to select between ssl or not)

* Console in root folder:
    *$ you must create a *conf.rb* file (I use [mailgun](https://www.mailgun.com/)). Content:
        $mail_key='https://api:key-...'
        $from='Mailgun Sandbox <postmaster@sandbox...'
    *$ rethinkdb
    *$ rethinkdb restore demo.tar.gz (if you haven't done yet)
    *see the document 'openssl_howto.txt' if you execute in rvmsudo mode

* Console in server folder:

    * $ ruby start.rb

* Open browser in https://localhost or localhost:8000

API
---
Controller client side:
* watch(name, *args, &block) -> id
* stop_watch(id)
* task(command, \*args)
* rpc(command, \*args) -> promise

  you can send Time objects, but you have to use keyword arguments: rpc('date_middle', date_ini: Time.now, date_end: Time.now + 24*60*60)
  Behind the scenes: with the message sent to the server, there is an array *times* with the attrs that are Time instances. This is the
  way I construct Times in the other side. From the server side, in a rpc method, you can return a Time.

* insert(table, hsh) -> promise
* update(table, id, hsh) -> promise
* delete(table, id)
* login(user, password)
* logout
* start(app)

Controller server side:
* get table, id, symbolize=true -> doc
* get_unique table, filter -> doc
* owner? doc -> boolean
* i_timestamp! doc # sets the inserted timestamp
* u_timestamp! doc # sets the updated timestamp
* owner! doc # sets the user_id as owner in the doc

Globals
-------
Client side:
* $controller

Server side:
* $r

TODO
----
* change the name of files. For example rename client.rb for client_controller.rb
  ui.core.rb --> ui_utils.rb
  ui.rb --> app_ui.rb
  server.rb --> server_controller.rb
* lots of things
* Do you like the code name of the project? --> Bull
* delete code: client.rb def get_watch

Help
----
Please contact me if you would like to contribute to the project. All opinions are welcome.
