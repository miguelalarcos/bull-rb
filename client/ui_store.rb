require 'ui_core'
require 'reactive-ruby'

class Popover < React::Component::Base
  param :show
  param :close
  param :id
  param :target
  include AbstractPopover

  def content
    div do
      b{'hello'}
      div{' there'}
    end
  end
end

class Item < React::Component::Base
  param :item
  param :on_select
  param :is_store

  before_mount do
    state.quantity! 0
    state.price! params.item['price']
    state.unit! params.item['unit']

    state.show_popover! 'hidden'
    state.target! nil
  end

  def render
    span(style: {float: 'left'}) do
      Popover(id:'popover'+params.item['id'], target: state.target, show: state.show_popover, close: lambda{state.show_popover! 'hidden'})
      div(class: 'item') do
        div(id:'target'+params.item['id']){params.item['name']}.on(:click) {|event| state.target! 'target'+params.item['id']; state.show_popover! 'visible'}
        div{b{params.item['quantity'].to_s}}
        IntegerInput(placeholder: 'quantity', on_change: lambda{|v| state.quantity! v}, value: state.quantity)
        div{params.item['price'].to_s+' €, ' + params.item['unit']}
        div do
          FloatInput(placeholder: 'price', on_change: lambda{|v| state.price! v}, value: state.price)
          StringInput(placeholder: 'unit', on_change: lambda{|v| state.unit! v}, value: state.unit)
        end if params.is_store
        button{'guardar'}.on(:click){params.on_select.call params.item, state.quantity, state.price, state.unit; state.quantity! 0}
      end
    end
  end
end

class Lines < DisplayList

  before_mount do
    watch_ 'lines', []
  end

  def render
    div(style: {clear: 'both'}) do
      table do
        tr do
          th{'Product'}
          th{'Quantity'}
          th{'Unit'}
          th{'Price'}
          th{'Total'}
        end
        state.docs.each do |doc|
          tr do
            td{doc['item_name']}
            td{doc['quantity'].to_s}
            td{doc['unit']}
            td{doc['price'].to_s}
            td{(doc['quantity']*doc['price']).to_s}
            td{button{'cancel'}.on(:click){$controller.task('cancel_line', doc['id'])}}
          end
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
        Item(is_store: false, item: item, on_select: lambda {|i, q, p, u| on_select i, q, p, u})
      end
      Lines()
    end
  end

  def on_select item, quantity, price, unit
    $controller.task('sale', item['id'], quantity, price, unit)
  end
end

class Store < DisplayList

  before_mount do
    clear_form
    watch_ 'items', []
  end

  def clear_form
    state.name! ''
    state.price! nil
    state.unit! ''
  end

  def render
    div do
      state.docs.each do |item|
        Item(is_store: true, item: item, on_select: lambda{|i, q, price, unit| on_select i, q, price, unit})
      end
      StringInput(placeholder: 'name', on_change: lambda{|v| state.name! v}, value: state.name)
      FloatInput(placeholder: 'price', on_change: lambda{|v| state.price! v}, value: state.price)
      StringInput(placeholder: 'unit', on_change: lambda{|v| state.unit! v}, value: state.unit)
      button{'create item'}.on(:click)do
        $controller.insert('item', {name: state.name, price: state.price, unit: state.unit, quantity: 0})
        clear_form
      end
    end
  end

  def on_select item, quantity, price, unit
    $controller.task('store', item['id'], quantity, price, unit)
  end
end

class App < React::Component::Base
  before_mount do
    state.show_popup! 'hidden'
    state.target! nil
  end

  def render
    div do
      Notification(level: 0)
      Sales()
      hr
      Store()
      #Popover(id:'popover', target_id: 'my_input', show: state.show_popup, close: lambda{state.show_popup! 'hidden'})
    end
  end
end