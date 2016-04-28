require 'ui_core'
require 'reactive-ruby'
require 'reactive_var'
require 'date-time-picker'
require 'autocomplete'
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
    state.date! nil
    state.datetime! nil
    state.auto! ''
    state.check! false
    state.array! []
    state.hash! Hash.new
    state.radio! 'yellow'
    state.select! 'yellow'
    state.mselect! ['yellow', 'red']
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
        tr do
          td{'Date'}
          td{DateTimeInput(time: false, format: '%d-%m-%Y', value: state.date,
                           on_change: change_attr('date'), dirty: state.dirty_date)}
        end
        tr do
          td{'DateTime'}
          td{DateTimeInput(time: true, format: '%d-%m-%Y %H:%M', value: state.datetime,
                           on_change: change_attr('datetime'), dirty: state.dirty_datetime)}
        end
        tr do
          td{'Autocomplete'}
          td{AutocompleteInput(ref_: 'location', name: 'name', value: state.auto,
                               on_change: change_attr('auto'), dirty: state.dirty_auto)}
        end
        tr do
          td{'Check'}
          td{CheckInput(value: state.check, on_change: change_attr('check'))}
        end
        tr do
          td{'Array'}
          td{ArrayInput(value: state.array, on_change: change_attr('array'))}
        end
        tr do
          td{'Hash'}
          td{HashInput(value: state.hash, on_change: change_attr('hash'))}
        end
        tr do
          td{'Radio'}
          td{RadioInput(value: state.radio, values: ['yellow', 'red', 'blue'], name: 'color',
                        on_change: change_attr('radio'))}
        end
        tr do
          td{'Select'}
          td{SelectInput(value: state.select, options: ['yellow', 'red', 'blue'],
                         on_change: change_attr('select'), dirty: state.dirty_select)}
        end
        tr do
          td{'Multiple select'}
          td{MultipleSelectInput(value: state.mselect, options: ['yellow', 'red', 'blue'],
                                 on_change: change_attr('mselect'))}
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
    state.date! nil
    state.datetime! nil
    state.auto! ''
    state.check! false
    state.array! []
    state.hash! Hash.new
    state.radio! ''
    state.select! nil
    state.mselect! nil
  end

  def render
    div do
      div{"The doc with id #{state.id} has these values:"}
      div{state.cte}
      div{state.string_a}
      div{state.integer_x.to_s}
      div{state.nested_float_y['value'].to_s}
      div{state.observations}
      div{state.date.strftime('%d-%m-%Y %H:%M')}
      div{state.datetime.strftime('%d-%m-%Y %H:%M')}
      div{state.auto}
      div{state.check.to_s}
      div{state.array.to_s}
      div{state.hash.to_s}
      div{state.radio}
      div{state.select}
      div{state.mselect.to_s}
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