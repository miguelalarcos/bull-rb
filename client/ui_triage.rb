require 'ui_core'
require 'reactive-ruby'
require 'reactive_var'
require 'date-time-picker'

class TriageList < DisplayList
  param :selected

  def tr_class doc
    if !doc['end_date'].nil?
      'triage-closed'
    else
      ''
    end
  end

  def sort docs
    docs.sort{|a, b| a['ini_date'] <=> b['ini_date']}
  end

  def render
    div do
      table do
        tr do
          th{'nhc'}
          th{'nombre'}
          th{'fecha inicio'}
          th{'feccha fin'}
        end
        state.docs.each do |doc|
          tr(class: tr_class(doc)) do
            td{doc['nhc'].to_s}
            td{doc['name']}
            td{doc['ini_date'].strftime('%d-%m-%Y %H:%M')}
            td{a(href: '#'){'select'}.on(:click){selected.value = doc['id']}}
            td{a(href: '#'){'close'}.on(:click){$controller.update('triage', doc['id'], {end_date: Time.new})}}
          end
        end
      end
    end
  end
end

class PatientSearch < React::Component::Base
  param :on_select

  before_mount do
    state.nhc! nil
    state.name! ''
    state.patients! []
  end

  def search
    $controller.rpc('search_patient', state.nhc, state.name).then do |docs|
      state.patients! docs
    end
  end

  def render
    div do
      div{IntegerInput(value: state.nhc, on_change: lambda{|v| state.nhc! v})}
      div{StringInput(value: state.name, on_change: lambda{|v| state.name! v})}
      button{'search'}.on(:click){search} if state.nhc || state.name != ''
      table do
        th{'nhc'}
        th{'name'}
        state.patients.each do |patient|
          td{patient['nhc'].to_s}
          td{patient['name']}
          td{a(href: '#'){'select'}.on(:click){params.on_select.call patient}}
        end
      end
    end
  end
end

class TriageAdministrativeForm < Form
  param :selected
  @@table = 'triage'
  @@constants = ['patient_id', 'nhc', 'name']

  before_mount do
    get params.selected
    state.ini_date! Time.new
    state.valid! true
  end

  def clear
    state.ini_date! Time.new
  end

  def render
    div do
      div{DateTimeInput(value: state.ini_date, format: '%d-%m-%Y %H:%M', on_change: change_attr('ini_date'))}
      FormButtons()
    end
  end
end

class TriageClinicalForm < Form
  @@table = 'triage'
  param :selected

  before_mount do
    get params.selected
    state.valid! true
  end

  def clear
    state.observations! ''
  end

  def render
    div do
      div{MultiLineInput(value: state.observations, on_change: change_attr('observations'))}
      FormButtons()
    end
  end
end

class MyModal < React::Component::Base
  include Modal
  param :ok

  def content
    div do
      h2{'There are data not saved. Save or discard the data.'}
      button{'accept'}.on(:click) {params.ok.call}
    end
  end
end

class UserForm < Form
  @@table = 'user'
  param :selected

  before_mount do
    get_unique user: 'miguel'
  end

  def render
    ArrayInput(value: state.roles, on_change: lambda{|v| state.roles! v})
    FormButtons()
  end

end

class App < React::Component::Base
  before_mount do
    @selected = RVar.new nil
    @user_selected = RVar.new 'miguel'
    state.modal! false
    state.patient! nil
  end

  def render
    div do
      Notification(level: 0)
      UserForm(selected: @user_selected)
      PatientSearch(on_select: lambda{|v| state.patient! v})
      TriageAdministrativeForm(selected: @selected, patient_id: state.patient['patient_id'],
                                                    nhc: state.patient['nhc'],
                                                    name: state.patient['name'])
      TriageClinicalForm(selected: @selected)
      TriageList(selected: @selected, show_modal: lambda{state.modal! true})
      MyModal(ok: lambda {state.modal! false}) if state.modal
    end
  end
end