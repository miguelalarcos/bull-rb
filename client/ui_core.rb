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

  param :change_attr, type: Proc
  param :value, type: String

  def render
    div do
      input(type: :text, value: params.value){}.on(:change) do |event|
          update_state
      end
    end
  end
end

class StringInput < AttrInput
  def update_state
      params.change_attr event.target.value
  end
end

class FloatInput < AttrInput
  def update_state
    begin
      params.change_attr Float(event.target.value)
    rescue
    end
  end
end

class IntegerInput < AttrInput
  def update_state
    begin
      params.change_attr Integer(event.target.value)
    rescue
    end
  end
end

class Form < React::Component::Base

  before_mount do
    @dirty = Set.new
  end

  def change_attr(attr)
    lambda do |value|
      @dirty.add attr
      state.__send__(attr+'!', value)
    end
  end

  def update
    ret = {}
    @dirty.each do |attr|
      ret[attr] = state.__send__(attr) if attr != 'id'
    end
    @dirty.clear
    $controller.rpc('update', @@table, state.id, ret)
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

