require 'reactive-ruby'
require 'set'
require_relative 'reactive_var'
require_relative 'lib/utils'
require_relative 'bcaptcha'
require 'ui_common'
require 'time'

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
        data['new_val'].each {|k, v| state.__send__(k+'!', v)} if !(data.nil? || data['new_val'].nil?)
      end
    end
  end

  before_unmount do
    $controller.stop_watch @predicate_id if @predicate_id != nil
    @rvs.each_pair {|k, v| v.remove k} if @rvs
  end
end

module AbstractStringInput
  include ClassesInput
  def render
    span do
      input(placeholder: params.placeholder, class: valid_class + ' ' + dirty_class,
            type: type_attr, value: params.value){}.on(:change) do |event|
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
  param :valid
  param :dirty

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
  param :valid
  param :dirty

  def type_attr
    :password
  end
end

class MultiLineInput < React::Component::Base
  param :on_change, type: Proc
  param :on_enter
  param :value
  param :placeholder
  param :valid
  param :dirty

  include ClassesInput

  def render
    textarea(placeholder: params.placeholder, class: valid_class + ' ' + dirty_class,
             value: params.value){}.on(:change) do |event|
      params.on_change event.target.value
    end.on(:keyDown) do |event|
      if event.key_code == 13
        params.on_enter.call event.target.value
      end
    end
  end
end

=begin
class DateInput < React::Component::Base
  param :on_change, type: Proc
  param :value
  param :format
  param :valid
  param :dirty

  include ClassesInput

  before_mount do
    state.value! ''
    state.year! ''
  end

  def date(value, year)
    begin # opal: undefined method `strptime' for Time
      Time.strptime(value+year, params.format+'%Y'){|y| y < 100 ? (y >= 69 ? y + 1900 : y + 2000) : y}
    rescue
      nil
    end
  end


  def render
    if params.value.nil?
      value = state.value
      year = state.year
    else
      value = params.value.format params.format
      year = params.value.year.to_s
    end
    span do
      input(class: valid_class + ' ' + dirty_class, value: value).on(:change) do |event|
        state.value! event.target.value
        params.on_change date(event.target.value, year)
      end
      input(value: year).on(:change) do |event|
        state.year! event.target.value
        params.on_change date(value, event.target.value)
      end
    end
  end
end
=end

module AbstractNumeric
  include ClassesInput

  def format val
    val.to_s
  end

  def render
    if parse(state.value) != params.value
      value = params.value.to_s
    else
      value = state.value
    end

    span do
      input(placeholder: params.placeholder, class: valid_class + ' ' + dirty_class, type: :text, value: format(value)){}.on(:change) do |event|
          state.value! event.target.value
          if event.target.value == ''
            params.on_change nil
          else
            update_state event
          end
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
  param :valid
  param :on_enter
  param :placeholder
  param :dirty

  def parse val
    begin
      Integer(val)
    rescue
      nil
    end
  end

  def update_state event
    params.on_change parse(event.target.value)
  end
end

def format_integer value
  path = value.to_s.reverse.split(/(\d\d\d)/).select{|v| v != ''}
  if path[0] == '-'
    path.shift
    '-' + path.join(',').reverse
  else
    path.join(',').reverse
  end
end

def format_float value
  e, d = value.to_s.split('.')
  d = '' if value.to_s.end_with?('.')
  return '' if e.nil?
  v = format_integer e
  if d.nil?
    v
  else
    v + '.' + d
  end
end

class IntegerCommaInput < React::Component::Base
  include AbstractNumeric

  param :on_change, type: Proc
  param :value, type: Integer
  param :valid
  param :on_enter
  param :placeholder
  param :dirty

  def format value
    format_integer value
  end

  def parse val
    begin
      Integer(val.gsub(',', ''))
    rescue
      nil
    end
  end

  def update_state event
    params.on_change parse(event.target.value)
  end
end

class FloatInput < React::Component::Base
  include AbstractNumeric

  param :on_change, type: Proc
  param :value, type: Float
  param :valid
  param :on_enter
  param :placeholder
  param :dirty

  def parse val
    begin
      Float(val)
    rescue
      nil
    end
  end

  def update_state event
    params.on_change parse(event.target.value)
  end
end

class FloatCommaInput < React::Component::Base
  include AbstractNumeric

  param :on_change, type: Proc
  param :value, type: Float
  param :valid
  param :on_enter
  param :placeholder
  param :dirty

  def format value
    format_float value
  end

  def parse val
    begin
      Float(val.gsub(',', ''))
    rescue
      nil
    end
  end

  def update_state event
    params.on_change parse(event.target.value)
  end
end

class CheckInput < React::Component::Base
  param :value
  param :on_change

  def render
   input(type: :checkbox, checked: params.value).on(:change){params.on_change.call !params.value}
  end
end

class RadioInput < React::Component::Base
  param :value
  param :values
  param :name
  param :on_change

  def render
    span do
      params.values.each do |v|
        input(type: :radio, name: params.name, value: v, checked: v == params.value){v}.on(:change){params.on_change.call v}
      end
    end
  end
end

class HashInput < React::Component::Base
  param :value
  param :on_change

  before_mount do
    state.key! ''
    state.value! ''
  end

  def render
    span do
      input(placeholder: 'key', value: state.key).on(:change){|event| state.key! event.target.value}
      input(placeholder: 'value',value: state.value).on(:change){|event| state.value! event.target.value}
      button{'add'}.on(:click) do
        hsh = params.value.dup
        hsh[state.key] = state.value
        params.on_change.call hsh
        state.key! ''
        state.value! ''
      end
      table do
        tr do
          th{'key'}
          th{'value'}
          th{' '}
        end
        params.value.each_pair do |k, v|
          tr do
            td{k}
            td{v}
            td{i(class: 'fa fa-times')}.on(:click) do
              hsh = params.value.dup
              hsh.delete k
              params.on_change.call hsh
            end
          end
        end
      end
    end
  end
end

class ArrayInput < React::Component::Base
  param :value
  param :on_change

  before_mount do
    state.v! ''
  end

  def render
    span do
      input(value: state.v).on(:change) do |event|
          state.v! event.target.value
        end.on(:keyDown) do |event|
        if event.key_code == 13
          list = params.value.dup
          list << event.target.value
          params.on_change.call list
          state.v! ''
        end
      end
      table do
        tr do
          th{'        '}
          th{'  '}
        end
        params.value.each do |v|
          tr do
            td{v}
            td{i(class: 'fa fa-times')}.on(:click) do
              list = params.value.dup
              list.delete v
              params.on_change.call list
            end
          end
        end
      end
    end
  end
end

class SelectInput < React::Component::Base
  param :on_change
  param :value
  param :options
  param :dirty

  include ClassesInput

  def render
    span do
      select(class: 'select ' + dirty_class, value: params.value) do
        option{''}
        params.options.each {|val| option(value: val){val}}
      end.on(:change) {|event| params.on_change.call event.target.value}
    end
  end
end

class MultipleSelectInput < React::Component::Base
  param :on_change
  param :options
  param :value

  def render
    span do
      select(class: 'select ', multiple: true, value: params.value) do
        option{''}
        params.options.each {|val| option(value: val){val}} #(selected: params.values.include? val){val}}
      end.on(:change) do |event|
        list = params.value.dup
        if list.include? event.target.value
          list.delete event.target.value
        else
          list << event.target.value
        end
        params.on_change.call list
      end
=begin
      table do
        tr do
          th{'        '}
          th{'  '}
        end
        params.values.each do |v|
          tr do
            td{v}
            td{i(class: 'fa fa-times fa-2x')}.on(:click) do
              list = params.values.dup
              list.delete v
              params.on_change.call list
            end
          end
        end
      end
=end
    end
  end
end

class FormButtons < React::Component::Base
  param :valid
  param :dirty
  param :save
  param :discard

  before_mount do
    state.discard! false
  end

  def render
    div do
      i(class: 'save fa fa-floppy-o fa-2x').on(:click){params.save.call} if params.valid && params.dirty
      i(class: 'discard fa fa-times fa-2x').on(:click) do
        if params.dirty
          state.discard! true
        else
          params.discard.call
        end
      end if !state.discard
      i(class: 'rdiscard fa fa-times fa-4x').on(:click) {params.discard.call; state.discard! false} if state.discard
    end
  end
end

class Form < React::Component::Base

  before_mount do
    @dirty = Set.new
    @refs = {}
    state.discard! false
    state.dirty! false
  end

  before_unmount do
    @rvs.each_pair {|k, v| v.remove k; v.remove_form self} if @rvs
  end

  def dirty?
    !@dirty.empty?
  end

  def change_attr(attr)
    lambda do |value|
      @dirty.add attr
      doc = state.__send__(attr.split('.')[0])
      set_nested(attr, value, doc){|r, v| state.__send__(r+'!', v)}
      state.__send__('dirty_' + attr.gsub('.', '_') + '!', true)
      state.dirty! true
    end
  end

  def hash_from_state
    ret = {}
    @dirty.each do |attr|
      get_nested!(ret, attr) {|r| state.__send__(r)}
    end
    @@constants.each do |cte|
      get_nested!(ret, cte) {|r| params.__send__(r)}
    end if @@constants
    ret
  end

  def save
    if state.id
      update
    else
      insert
    end
    state.discard! false
    state.dirty! false
  end

  def clear_dirty
    @dirty.each {|attr| state.__send__('dirty_' + attr.gsub('.', '_')+'!', false)}
    @dirty.clear
  end

  def discard
    @selected.value = nil
    clear
    #@dirty.each {|attr| state.__send__('dirty_' + attr+'!', false)}
    #@dirty.clear
    clear_dirty
    state.discard! false
    state.dirty! false
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
    #@dirty.each {|attr| state.__send__('dirty_' + attr+'!', false)}
    #@dirty.clear
    clear_dirty
  end

  def update
    $controller.update(@@table, state.id, hash_from_state).then do |count|
      if count == 0
        $notifications.add ['error', 'form: data not updated', 1] if $notifications
      elsif count == 1
        $notifications.add ['ok', 'form: data updated', 1] if $notifications
      end
    end
    #@dirty.each {|attr| state.__send__('dirty_' + attr.gsub('.', '_')+'!', false)}
    #@dirty.clear
    clear_dirty
  end

  def get selected
    @selected = selected
    selected.add_form self
    @rvs = reactive(selected) do
      @dirty.each {|attr| state.__send__('dirty_' + attr+'!', false)}
      @dirty.clear
      clear
      $controller.rpc('get_' + @@table, selected.value).then do|response|
        response.each do |k, v|
          state.__send__(k+'!', v)
        end
      end
    end
  end

  def get_unique kw
    k, selected = kw.shift
    @selected = selected
    selected.add_form self
    @rvs = reactive(selected) do
      @dirty.each {|attr| state.__send__('dirty_' + attr+'!', false)}
      @dirty.clear
      clear
      $controller.rpc('get_unique_' + @@table, k, selected.value).then do|response|
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

class HorizontalMenu < React::Component::Base
  param :options
  param :set_page
  param :page
  param :language

  def active page
    params.page == page ? 'active': ''
  end

  def render
    div(class: 'no-print') do
      ul(class: 'menu') do
        params.options.each_pair do |k, v|
          li(class: 'menu-item ' + active(k)){a(href: '#'){v}.on(:click){params.set_page.call k}}
        end
        li{a(href: '#'){'en'}.on(:click){params.language.value = 'en'}}
        li{a(href: '#'){'es'}.on(:click){params.language.value = 'es'}}
      end
    end
  end
end