require 'reactive-ruby'
require 'set'
require_relative 'reactive_var'

class NotificationController
  @@ticket = 0

  def initialize state
    @state = state
  end

  def add msg
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
  before_mount do
    state.notifications! Hash.new
    $notifications = NotificationController.new state
  end

  def render
    div do
      state.notifications.each_pair do |k, (animation, code, v)|
        div(key: k, class: animation + ' notification ' + code){v}#.on(:click) do
          #aux = state.notifications
          #aux[k] = ['animated fadeOut'] + aux[k][1..-1]
          #state.notifications! aux
          #$window.after(2) do
          #  aux = state.notifications
          #  aux.delete k
          #  state.notifications! aux
          #end
        #end
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

class Form < React::Component::Base
  #param :selected

  before_mount do
    @dirty = Set.new
  end

  before_unmount do
    @rvs.each_pair {|k, v| v.remove k} if @rvs
  end

  def change_attr(attr)
    lambda do |value|
      @dirty.add attr
      state.__send__(attr+'!', value)
    end
  end

  def hash_from_state
    ret = {}
    @dirty.each do |attr|
      ret[attr] = state.__send__(attr) if attr != 'id'
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
        $notifications.add ['error', 'data not inserted'] if $notifications
      else
        params.selected.value = response
        $notifications.add ['ok', 'data inserted'] if $notifications
      end
    end
    @dirty.clear
  end

  def update
    $controller.update(@@table, state.id, hash_from_state).then do |count|
      if count == 0
        $notifications.add ['error', 'data not updated'] if $notifications
      elsif count == 1
        $notifications.add ['ok', 'data updated'] if $notifications
      end
    end
    @dirty.clear
    #ret
  end

  def get selected
    @rvs = reactive(selected) do
      clear
      $controller.rpc('get_' + @@table, selected.value).then do|response|
        response.each do |k, v|
          state.__send__(k+'!', v)
        end
      end
    end
  end
end

