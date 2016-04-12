require 'reactive-ruby'
require 'set'
require_relative 'reactive_var'
require_relative 'lib/utils'
require_relative 'bcaptcha'

class NotificationController
  @@ticket = 0

  def initialize state, level
    @state = state
    @level = level
  end

  def add msg
    return if msg[-1] < @level
    id = @@ticket
    @@ticket += 1
    aux = @state.notifications
    aux[id] = ['animated fadeIn'] + msg
    @state.notifications! aux
    $window.after(2) do
      aux = @state.notifications
      aux[id] = ['animated fadeOut'] + aux[id][1..-1]
      @state.notifications! aux
    end
    $window.after(3) do
      aux = @state.notifications
      aux.delete id
      @state.notifications! aux
    end
  end
end

class Notification < React::Component::Base
  param :level

  before_mount do
    state.notifications! Hash.new
    $notifications = NotificationController.new state, params.level
  end

  def render
    div(style: {position: 'absolute'}) do
      state.notifications.each_pair do |k, (animation, code, v, level)|
        div(key: k, class: animation + ' notification ' + code){v}
      end
    end
  end
end

class DisplayList < React::Component::Base

  before_mount do
    state.docs! []
    @predicate_id = nil
  end

  def watch_(name, *args)
    clear
    $controller.stop_watch(@predicate_id) if @predicate_id != nil
    @predicate_id = $controller.watch(name, *args) {|data| consume data}
  end

  def consume data
    if data.nil?
      clear
      return
    end
    docs = state.docs.dup
    if data['new_val'] == nil
      index = docs.index {|x| x['id'] == data['old_val']['id']}
      docs.delete_at index
    elsif data['old_val'] == nil
      docs << data['new_val']
    else
      index = docs.index {|x| x['id'] == data['old_val']['id']}
      doc = docs.fetch index
      doc.merge! data['new_val']
    end
    state.docs! sort(docs)
  end

  def clear
    state.docs! []
  end

  def sort docs
    docs
  end

  before_unmount do
    $controller.stop_watch @predicate_id if @predicate_id != nil
  end
end

class DisplayDoc < React::Component::Base

  before_mount do
    @predicate_id = nil
  end

  def watch_ selected
    @rvs = reactive(selected) do
      value = selected.value
      clear
      $controller.stop_watch(@predicate_id) if @predicate_id != nil
      @predicate_id = $controller.watch(@@table, value) do |data|
        if data.nil?
          clear
        else
          data['new_val'].each {|k, v| state.__send__(k+'!', v)}
        end
      end
    end
  end

  before_unmount do
    $controller.stop_watch @predicate_id if @predicate_id != nil
    @rvs.each_pair {|k, v| v.remove k} if @rvs
  end
end

class AttrInput < React::Component::Base

  def render
    div do
      input(type: :text, value: params.value){}.on(:change) do |event|
          update_state
      end
    end
  end
end

module AbstractStringInput

  def render
    div do
      input(type: type_attr, value: params.value){}.on(:change) do |event|
        params.change_attr event.target.value
      end
    end
  end
end

class StringInput < React::Component::Base
  include AbstractStringInput

  param :change_attr, type: Proc
  param :value, type: String

  def type_attr
    :text
  end
end

class PasswordInput < React::Component::Base
  include AbstractStringInput

  param :change_attr, type: Proc
  param :value, type: String

  def type_attr
    :password
  end
end

module AbstractNumeric
  def render
    value = params.value
    if value.nil?
      value = ''
    end
    div do
      input(type: :text, value: value.to_s){}.on(:change) do |event|
        begin
          if event.target.value == ''
            params.change_attr nil
          else
            update_state event
          end
        rescue
        end
      end
    end
  end
end

class IntegerInput < React::Component::Base
  include AbstractNumeric

  param :change_attr, type: Proc
  param :value, type: Integer

  def update_state event
    params.change_attr Integer(event.target.value)
  end
end

class FloatInput < React::Component::Base
  include AbstractNumeric

  param :change_attr, type: Proc
  param :value, type: Float

  def update_state event
    params.change_attr Float(event.target.value)
  end
end

def selected val1, val2
  if val1 == val2
    {:selected => 'selected'}
  else
    {}
  end
end

class SelectInput < React::Component::Base
  param :change_attr
  param :value
  param :options

  def render
    select(class: 'form-control') do
      option{''}
      params.options.each {|val| option(selected(params.value, val)){val}}
    end.on(:change) {|event| params.change_attr.call event.target.value}
  end
end

class Form < React::Component::Base
  #param :selected

  before_mount do
    @dirty = Set.new
    @refs = {} #Set.new
  end

  before_unmount do
    @rvs.each_pair {|k, v| v.remove k} if @rvs
  end

  def add_ref attr
    #lambda {|ref| @refs.add ref; print '->', ref}
    lambda {|b| @refs[attr] = b}
  end

  def change_attr(attr)
    lambda do |value|
      @dirty.add attr
      doc = state.__send__(attr.split('.')[0])
      set_nested_state(attr, value, doc){|r, v| state.__send__(r+'!', v)}
    end
  end

  def hash_from_state
    ret = {}
    @dirty.each do |attr|
      get_nested_state!(ret, attr) {|r| state.__send__(r)}
    end
    ret
  end

  def save
    if state.id
      update
    else
      insert
    end
  end

  def insert
    $controller.insert(@@table, hash_from_state).then do |response|
      if response.nil?
        $notifications.add ['error', 'form: data not inserted', 1] if $notifications
      else
        params.selected.value = response
        $notifications.add ['ok', 'form: data inserted', 1] if $notifications
      end
    end
    @dirty.clear
  end

  def update
    $controller.update(@@table, state.id, hash_from_state).then do |count|
      if count == 0
        $notifications.add ['error', 'form: data not updated', 1] if $notifications
      elsif count == 1
        $notifications.add ['ok', 'form: data updated', 1] if $notifications
      end
    end
    @dirty.clear
    #ret
  end

  def get selected
    @rvs = reactive(selected) do
      @dirty.clear
      clear
      $controller.rpc('get_' + @@table, selected.value).then do|response|
        @fields_ref.each {|k| @refs[k] = true }#.add([table, field, response[k]])} if @fields_ref
        response.each do |k, v|
          state.__send__(k+'!', v)
        end
      end
    end
  end
end

module Modal
  def render
    div(class: 'modal') do
      div(class: 'modal-center') do
        content
      end
    end
  end
end
