require 'reactive-ruby'
require 'set'
require_relative 'reactive_var'
require_relative 'lib/utils'
require_relative 'bcaptcha'

module ValidInput
  def valid_class
    return '' if params.is_valid.nil?
    if params.is_valid
      'input-successful'
    else
      'input-incorrect'
    end
  end
end

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
    reactives = args.pop
    @rvs = reactive(*reactives) do
      clear
      $controller.stop_watch(@predicate_id) if @predicate_id != nil
      @predicate_id = $controller.watch(name, *args) {|data| consume data}
    end
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
    @rvs.each_pair {|k, v| v.remove k} if @rvs
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
        clear
        data['new_val'].each {|k, v| state.__send__(k+'!', v)} if !data.nil?
        #if data.nil?
        #  clear
        #else
        #  data['new_val'].each {|k, v| state.__send__(k+'!', v)}
        #end
      end
    end
  end

  before_unmount do
    $controller.stop_watch @predicate_id if @predicate_id != nil
    @rvs.each_pair {|k, v| v.remove k} if @rvs
  end
end

module AbstractStringInput
  include ValidInput
  def render
    span do
      input(placeholder: params.placeholder, class: valid_class, type: type_attr, value: params.value){}.on(:change) do |event|
        params.on_change event.target.value
      end.on(:keyDown) do |event|
        if event.key_code == 13
          params.on_enter.call event.target.value
        end
      end
    end
  end
end

class StringInput < React::Component::Base
  include AbstractStringInput

  param :on_change, type: Proc
  param :value, type: String
  param :placeholder
  param :on_enter
  param :is_valid

  def type_attr
    :text
  end
end

class PasswordInput < React::Component::Base
  include AbstractStringInput

  param :on_change, type: Proc
  param :value, type: String
  param :placeholder
  param :on_enter
  param :is_valid

  def type_attr
    :password
  end
end

module AbstractNumeric
  include ValidInput

  def render
    value = params.value
    if value.nil?
      value = ''
    end
    span do
      input(placeholder: params.placeholder, class: valid_class, type: :text, value: value.to_s){}.on(:change) do |event|
        #begin
          if event.target.value == ''
            params.on_change nil
          else
            update_state event
          end
        #rescue
        #end
      end.on(:keyDown) do |event|
        if event.key_code == 13
          params.on_enter.call event.target.value
        end
      end
    end
  end
end

class IntegerInput < React::Component::Base
  include AbstractNumeric

  param :on_change, type: Proc
  param :value, type: Integer
  param :is_valid
  param :on_enter
  param :placeholder

  def update_state event
    begin
      params.on_change Integer(event.target.value)
    rescue
      params.on_change event.target.value
    end
  end
end

class FloatInput < React::Component::Base
  include AbstractNumeric

  param :on_change, type: Proc
  param :value, type: Float
  param :is_valid
  param :on_enter
  param :placeholder

  def update_state event
    val = event.target.value
    begin
      if val == '-0'
        params.on_changer val
      else
        params.on_change Float(val)
      end
    rescue
      params.on_change val
    end
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
  param :on_change
  param :value
  param :options

  def render
    span do
      select(class: 'select') do
        option{''}
        params.options.each {|val| option(selected(params.value, val)){val}}
      end.on(:change) {|event| params.on_change.call event.target.value}
    end
  end
end

class Form < React::Component::Base

  before_mount do
    @dirty = Set.new
    @refs = {}
  end

  before_unmount do
    @rvs.each_pair {|k, v| v.remove k; v.remove_form self} if @rvs
  end

  def dirty?
    !@dity.empty?
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
      get_nested!(ret, attr) {|r| state.__send__(r)}
    end
    @@constants.each do |cte|
      get_nested!(ret, cte) {|r| params.__send__(r)}
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
    selected.add_form self
    @rvs = reactive(selected) do
      @dirty.clear
      clear
      $controller.rpc('get_' + @@table, selected.value).then do|response|
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

module AbstractPopover
  def render
    klass = 'inactive animated fadeOut'
    if params.show == 'visible'
      klass = 'active animated fadeIn'

      h = $document[params.target].height
      x = $document[params.target].position.x
      y = $document[params.target].position.y

      $document[params.id].offset.x = x
      $document[params.id].offset.y = y+h
      $window.after(5){params.close.call}
    end
    div(id: params.id) do
      div(class: 'popover ' + klass) do
        div(class: 'arrow-up')
        div(class: 'box') do
          div(class: 'close'){i(class: 'fa fa-times')}.on(:click){params.close.call}
          div(class: 'content'){content}
        end
      end
    end
  end
end

#example
=begin
class Popover < React::Component::Base
  param :show
  param :close
  param :id
  param :target_id
  include AbstractPopover

  def content
    div do
      b{'hello'}
      div{' there'}
    end
  end
end

Popover(id:'popover', target_id: 'my_input', show: state.show_popup, close: lambda{state.show_popup! 'hidden'})
#where show_popup can be 'visible' or 'hidden'
=end
