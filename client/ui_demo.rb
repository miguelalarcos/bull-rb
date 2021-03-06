require 'ui_core'
require 'reactive-ruby'
require 'reactive_var'
require 'login'
require 'date-time-picker'
require 'autocomplete'
require 'login'
require 'validation/validation_demo'
require 'i18n'

def format_float_sup_money value, symb
  integer, decimal = format_float(value).split('.')
  span do
    span{integer}
    sup{'.' + decimal} if !decimal.nil?
    span{symb}
  end
end

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
    state.radio! nil
    state.select! nil
    state.mselect! []
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
          td{IntegerCommaInput(valid: state.valid_integer_x, dirty: state.dirty_integer_x, placeholder: 'integer',
                          value: state.integer_x, on_change: change_attr('integer_x'))}
          td(class: 'error'){'integer must be > 10'} if !state.valid_integer_x
        end
        tr do
          td{'A nested float'}
          td{FloatCommaInput(key: 'float_y', valid: state.valid_nested_float_y_value, dirty: state.dirty_nested_float_y_value,
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
          td{AutocompleteInput(rmethod: 'location', value: state.auto, name: 'name',
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
  param :i18n_map
  #param :set_report_page

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
    context = {id: state.id}
    div do
      #div{"The doc with id #{state.id} has these values:"}
      div{i18n(params.i18n_map, 'DOC_TEXT')%context}
      div{state.cte}
      div{state.string_a}
      div{state.integer_x.to_s}
      div{state.nested_float_y['value'].to_s}
      div{format_integer state.integer_x}
      div(class: 'montserrat'){format_float_sup_money(state.nested_float_y['value'], '€')}
      div{state.observations}
      div{state.date.strftime('%d-%m-%Y') if state.date}
      div{state.datetime.strftime('%d-%m-%Y %H:%M') if state.datetime}
      div{state.auto}
      div{state.check.to_s}
      div{state.array.to_s}
      div{state.hash.to_s}
      div{state.radio}
      div{state.select}
      div{state.mselect.to_s}
      button(){'print doc'}.on(:click) do
        $controller.rpc('report_demo', params.selected.value).then do |report|
          `document.getElementById("report").innerHTML = #{report}`
        end
        #params.set_report_page.call
      end
    end
  end
end

class DemoList < DisplayList
  param :selected
  param :show_modal

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
          tr(key: doc['id']) do
            td{doc['id']}
            td{doc['string_a']}
            td{format_integer doc['integer_x']}
            td(class: 'montserrat'){format_float_sup_money(doc['nested_float_y']['value'], '€')}
            td{a(href: '#'){'delete'}.on(:click){$controller.delete('demo', doc['id'])}}
            td do
              a(href: '#'){'select'}.on(:click) do
                begin
                  RVar.raise_if_dirty do
                    params.selected.value = doc['id']
                  end
                rescue
                  $notifications.add ['error', 'There are data not saved. Save or discard the data.', 1] if $notifications
                  params.show_modal.call
                end
              end
            end
          end
        end
      end
    end
  end
end

class PageDemo < React::Component::Base
  param :show
  param :show_modal
  param :i18n_map

  before_mount do
    @selected = RVar.new nil
  end

  def klass
    c = params.show ? '': 'no-display'
    'demo-container ' + c
  end

  def render
    div(class: klass) do
      DemoForm(selected: @selected, cte: 'miguel')
      DemoDoc(i18n_map: params.i18n_map, selected: @selected)
      DemoList(selected: @selected, show_modal: params.show_modal)
    end
  end
end

class PageReport < React::Component::Base
  param :show

  def render
    div(class: params.show ? '': 'no-display') do
      i(class: "fa fa-print no-print fa-5x", style: {position: 'absolute'}).on(:click) {`window.print()`}
      div(id: 'report')
    end
  end
end

class PageLogin < React::Component::Base
  param :show
  param :user
  param :set_user
  param :set_roles

  before_mount do
    state.user! false
    state.create_user! false
    state.forgotten! false
  end

  def klass bool
    if bool
      'animated fadeIn'
    else
      'animated fadeOut'
    end
  end

  def render
    div(class: params.show ? '': 'no-display') do
      if params.user
        button{'logout'}.on(:click){$controller.logout; params.set_user.call false; params.set_roles.call []}
      else
        Login(set_user: params.set_user, set_roles: params.set_roles)
        a(href: '#'){'I want to create an user!'}.on(:click){state.create_user! !state.create_user}
        CreateUserNetCaptcha(klass: klass(state.create_user), set_user: params.set_user, set_roles: params.set_roles) if state.create_user
        a(href: '#'){'Have you forgotten the password?'}.on(:click){state.forgotten! !state.forgotten}
        ForgottenPassword(klass: klass(state.forgotten)) if state.forgotten
      end
    end
  end
end

class DirtyModal < React::Component::Base
  include Modal
  param :ok

  def content
    div do
      h2{'There are data not saved. Save or discard the data.'}
      button{'accept'}.on(:click) {params.ok.call}
    end
  end
end

class App < React::Component::Base

  before_mount do
    @language = RVar.new 'en'
    reactive(@language) do
      $controller.rpc('get_unique_i18n', @language.value).then do|response|
        state.i18n_map! response
      end
    end

    state.user! false
    state.roles! []
    state.page! 'demo'
    state.modal! false
    state.relogin! false
    $controller.set_relogin_state = lambda{|v| state.relogin! v}
  end

  def render
    div do
      Notification(level: 0)
      DirtyModal(ok: lambda {state.modal! false}) if state.modal
      Relogin() if state.relogin
      HorizontalMenu(language: @language, page: state.page, set_page: lambda{|v| state.page! v},
                     options: {'demo'=>'Demo', 'login'=>'Login', 'report' => 'Report'})
      PageDemo(i18n_map: state.i18n_map, key: 'page-demo', show: state.page == 'demo', show_modal: lambda{state.modal! true})
      PageLogin(user:state.user, set_user: lambda{|v| state.user! v}, set_roles: lambda{|v| state.roles! v}, show: state.page == 'login')
      PageReport(show: state.page == 'report')
    end
  end

end