require 'ui_core'
require 'reactive-ruby'
require 'reactive_var'
require 'date-time-picker'
require_relative '../validation/validation_demo'

class DemoForm < Form
  @@table = 'demo'

  before_mount do
    clear
  end

  def clear
    state.string_a! ''
    state.password! ''
    state.integer_x! nil
    y = {value: nil}
    state.nested_float_y! y
  end

  def render
    ValidateDemo.new.validate state
    table do
      tr do
        td{'A string'}
        td{StringInput(valid: state.valid_string_a, dirty: state.dirty_string_a, placeholder: 'string', value: state.string_a, on_change: change_attr('string_a'))}
        td(class: 'error'){'string must start with A'} if !valid_string_a
      end
      tr do
        td{'A password'}
        td{PasswordInput(placeholder: 'password', value: state.password, on_change: change_attr('password'))}
      end
      tr do
        td{'An integer'}
        td{IntegerInput(placeholder: 'integer', value: state.integer_x, on_change: change_attr('integer_x'))}
        td(class: 'error'){'integer must be > 10'} if !valid_string_a
      end
      tr do
        td{'A nested float'}
        td{FloatInput(placeholder: 'nested float', value: state.nested_float_y[:value], on_change: change_attr('nested_float_y.value'))}
        td(class: 'error'){'float must be negative'} if !valid_string_a
      end
    end
    FormButtons()
  end
end

class App < React::Component::Base
  before_mount do

  end

  def render
    div do
      Notification(level: 0)
      DemoForm()
    end
  end

end