require 'ui_core'
require 'reactive-ruby'
require 'reactive_var'
require 'date-time-picker'
require_relative 'validation/validation_demo'

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
    y = {value: nil}
    state.nested_float_y! y
    state.observations! ''
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
          td{IntegerInput(valid: state.valid_integer_x, dirty: state.dirty_integer_x, placeholder: 'integer',
                          value: state.integer_x, on_change: change_attr('integer_x'))}
          td(class: 'error'){'integer must be > 10'} if !state.valid_integer_x
        end
        tr do
          td{'A nested float'}
          td{FloatInput(valid: state.valid_nested_float_t_value, dirty: state.dirty_nested_float_t_value,
                        placeholder: 'nested float', value: state.nested_float_y[:value],
                        on_change: change_attr('nested_float_y.value'))}
          td(class: 'error'){'float must be negative'} if !state.valid_nested_float_y_value
        end
        tr do
          td{'Observations'}
          td{MultiLineInput(valid: state.valid_observations, dirty: state.dirty_observations,
                            value: state.observations, on_change: change_attr('observations'))}
        end
      end
      FormButtons(save: lambda{save}, discard: lambda{discard}, valid: state.valid, dirty: state.dirty)
    end
  end
end

class DemoDoc < DisplayDoc
  @@table = 'demo'
  param :selected

  before_mount do
    watch_ params.selected
  end

  def clear
    state.id! nil
    state.string_a! ''
    state.password! ''
    state.integer_x! nil
    y = {value: nil}
    state.nested_float_y! y
    state.observations! ''
  end

  def render
    div do
      div{state.id}
      div{state.cte}
      div{state.string_a}
      div{state.integer_x.to_s}
      div{state.nested_float_y['value'].to_s}
      div{state.observations}
    end
  end
end

class DemoList < DisplayList
  param :selected

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
          tr do
            td{doc['id']}
            td{doc['string_a']}
            td{doc['integer_x'].to_s}
            td{doc['nested_float_y']['value'].to_s}
            td{a(href: '#'){'select'}.on(:click){params.selected.value = doc['id']}}
          end
        end
      end
    end
  end
end

class PageDemo < React::Component::Base
  param :page

  before_mount do
    @selected = RVar.new nil
  end

  def render
    div(class: params.page == 'demo'? '': 'no-display' ) do
      DemoForm(selected: @selected, cte: 'miguel')
      DemoDoc(selected: @selected)
      DemoList(selected: @selected)
    end
  end
end

class PageLogin < React::Component::Base
  param :page

  def render
    div(class: params.page == 'login'? '': 'no-display') do
      'page of login!'
    end
  end
end

class Menu < React::Component::Base
  param :set_page
  def render
    div do
      a(href: '#'){'Demo'}.on(:click){params.set_page.call 'demo'}
      a(href: '#'){'Login'}.on(:click){params.set_page.call 'login'}
    end
  end
end

class App < React::Component::Base

  before_mount do
    state.page! 'demo'
  end

  def render
    div do
      Notification(level: 0)
      Menu(set_page: lambda{|v| state.page! v})
      PageDemo(page: state.page)
      PageLogin(page: state.page)
    end
  end

end