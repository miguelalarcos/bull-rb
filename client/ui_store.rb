require 'ui_core'
require 'reactive-ruby'

class Item < React::Component::Base
  param :item
  param :on_select
  param :is_store

  before_mount do
    state.quantity! 1
    state.price! nil
    state.unit! ''
  end

  def render
    span(class: 'item') do
      div{params.item['name']}
      div{b{params.item['quantity']}}
      IntegerInput(placeholder: 'quantity', on_change: lambda{|v| state.quantity! v}, value: state.quantity)
      span{params.item['price'].to_s+'€, ' + params.item['unit']}
      div do
        FloatInput(placeholder: 'price', on_change: lambda{|v| state.price! v}, value: state.price)
        StringInput(placeholder: 'unit', on_change: lambda{|v| state.unit! v}, value: state.unit)
      end if params.is_store
    end.on(:click){params.on_select.call params.item, sate.quantity, state.price, state.unit}
  end
end

class Lines < DisplayList

  before_mount do
    watch_ 'lines', []
  end

  def render
    div do
      state.docs.each do |doc|
        tr do
          td{doc['name']}
          td{doc['quantity']}
          td{doc['unit']}
          td{doc['price']}
          td{doc['unit']*doc['price']}
          td{button{'cancel'}.on(:click){$controller.task('cancel_line', doc['id'])}}
        end
      end
    end
  end
end

class Sales < DisplayList

  before_mount do
    watch_ 'items', []
  end

  def render
    div do
      state.docs.each do |item|
        Item(is_store: false, item: item, on_select: lambda {|i, q| on_select i, q})
      end
      Lines()
    end
  end

  def on_select item, quantity, price, unit
    $controller.task('sale', item['id'], quantity)
  end
end

class Store < DisplayList

  before_mount do
    clear_form
    watch_ 'items', []
  end

  def clear_form
    state.name! ''
    state.price! 0
    state.unit! ''
  end

  def render
    div do
      state.docs.each do |item|
        Item(is_store: true, item: item, on_select: lambda{|i, q| on_select i, q, price, unit})
      end
      StringInput(placeholder: 'name', on_change: lambda{|v| state.name! v}, value: state.name)
      FloatInput(placeholder: 'price', on_change: lambda{|v| state.price! v}, value: state.price)
      StringInput(placeholder: 'unit', on_change: lambda{|v| state.unit! v}, value: state.unit)
      button{'create item'}.on(:click)do
        $controller.insert('item', {name: state.name, price: state.price, unit: state.unit})
        clear_form
      end
    end
  end

  def on_select item, quantity, price, unit
    $controller.task('store', item['id'], quantity, price, unit)
  end
end

class App < React::Component::Base
  def render
    div do
      Notification(level: 0)
      #Sales()
      hr
      Store()
    end
  end
end