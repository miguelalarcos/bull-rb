require 'reactive-ruby'
require 'set'

class DisplayList < React::Component::Base

  before_mount do
    state.docs! {}
    @predicate_id = nil
  end

  def watch(name, *args)
    $controller.stop_watch(@predicate_id) if @predicate_id != nil
    @predicate_id = $controller.watch(name, *args) {|data| consume data}
  end

  def consume data
    docs = state.docs.clone
    if data['new_val'] == nil
      docs.delete data['old_val']['id']
    else data['old_val'] == nil
      docs[data['new_val']['id']] = data['new_val']
    end
    state.docs! docs
  end

  before_unmount do
    $controller.stop_watch @predicate_id if @predicate_id != nil
  end
end

class DisplayDoc < React::Component::Base

  before_mount do
    @predicate_id = nil
  end

  def watch(table, rvar)
    reactive(rvar) do
      $controller.stop_watch(@predicate_id) if @predicate_id != nil
      @predicate_id = $controller.watch('by_id', table) do |data|
        data['new_val'].each {|k, v| state.send(k+'!', v)}
      end
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
        params.change_attr event.target.value
      end
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
      state.send(attr+'!', value)
    end
  end

  def update
    ret = {}
    @dirty.each do |attr|
      ret[attr] = state.send(attr) if attr != 'id'
    end
    $controller.rpc('update', @@table, state.id, ret).then {|response| puts response}
    @dirty.clear
  end

  def get rvar
    reactive(rvar) do
      $controller.rpc('get', @@table, rvar.value).then do|response|
        response.each do |k, v|
          state.send(k+'!', v)
        end
      end
    end
  end
end