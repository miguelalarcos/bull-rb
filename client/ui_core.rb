require 'reactive-ruby'
require 'set'

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
    docs = state.docs.dup
    if data['new_val'] == nil
      index = docs.index {|x| x['id'] == data['old_val']['id']}
      docs.delete_at index
    elsif data['old_val'] == nil
      docs << data['new_val']
    else
      index = docs.index {|x| x['id'] == data['old_val']['id']}
      #if !index.nil?
      doc = docs.fetch index
      doc.merge! data['new_val']
      #else
      #  docs << data['new_val']
      #end
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

  def watch_ value
    clear
    $controller.stop_watch(@predicate_id) if @predicate_id != nil
    @predicate_id = $controller.watch('by_id', @@table, value) do |data|
      data['new_val'].each {|k, v| state.__send__(k+'!', v)}
    end
  end

  before_unmount do
    $controller.stop_watch @predicate_id if @predicate_id != nil
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

=begin
  def render
    div do
      input(type: :text, value: params.value){}.on(:change) do |event|
        update_state event
      end
    end
  end

  def update_state event
      params.change_attr event.target.value
  end
=end
end

class PasswordInput < React::Component::Base
  include AbstractStringInput

  param :change_attr, type: Proc
  param :value, type: String

  def type_attr
    :password
  end

=begin
  def render
    div do
      input(type: :password, value: params.value){}.on(:change) do |event|
        update_state event
      end
    end
  end

  def update_state event
    params.change_attr event.target.value
  end
=end
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
    #$controller.rpc('insert', @@table, hash_from_state).then do |response|
      params.selected.value = response['id']
    end
    @dirty.clear
  end

  def update
    ret = $controller.update(@@table, state.id, hash_from_state)
    #ret = $controller.rpc('update', @@table, state.id, hash_from_state)
    @dirty.clear
    ret
  end

  def get value
    clear
    $controller.rpc('get', @@table, value).then do|response|
      response.each do |k, v|
        state.__send__(k+'!', v)
      end
    end
  end
end

