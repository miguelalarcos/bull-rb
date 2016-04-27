require 'ui_core'
require 'reactive-ruby'
require 'reactive_var'
require 'bull-date-time-picker'

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
        end
        state.docs.each do |doc|
          tr(class: tr_class(doc)) do
            td{doc['nhc']}
            td{doc['name']}
            td{doc['ini_date'].strftime('%d-%m-%Y %H:%M')}
            td{'select'}.on(:click){selected.value = doc['id']}
            td{'close'}.on(:click){$controller.update('triage', doc['id'], {end_date: Time.new})}
          end
        end
      end
    end
  end
end

class TriageForm < Form
  @@table = 'triage'
  param :selected
  @@constants = ['nhc', 'name']

  before_mount do
    get params.selected
  end

  def clear
    state.nhc! nil
    state.name! ''
    state.ini_date! nil
    state.observations! ''
  end
  def render
    div do
      div{DateTimeInput(value: state.ini_date, format: '%d-%m-%Y %H:%M', on_change: change_attr('ini_date'))}
      div{MultiLineInput(value: state.observations, on_change: change_attr('observations'))}
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

class App < React::Component::Base
  before_mount do
    @selected = RVar.new nil
    state.modal! false
  end

  def render
    div do
      Notification(level: 0)
      TriageForm(selected: @selected)
      TriageList(selected: @selected, show_modal: lambda{state.modal! true})
      MyModal(ok: lambda {state.modal! false}) if state.modal
    end
  end
end