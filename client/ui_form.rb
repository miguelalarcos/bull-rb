require 'ui_core'
require 'reactive-ruby'
require 'reactive_var'

class MyForm < Form
  @@table = 'my_table'
  param :selected
  param :show_modal

  before_mount do
    get params.selected
  end

  def clear
    state.a! ''
  end

  def render
    div do
      StringInput(value: state.a, on_change: change_attr('a'), dirty: state.dirty_a)
      button{'save'}.on(:click){save}
      button{'discard'}.on(:click) {state.discard! true}
      button{'really discard!'}.on(:click) {discard} if state.discard
    end
  end
end

class MyList < DisplayList
  param :selected
  param :show_modal

  before_mount do
    watch_ 'my_table', []
  end

  def render
    div do
      state.docs.each do |doc|
        div(key: doc['id']){doc['a']}.on(:click) do
          begin
            RVar.raise_if_dirty do
              params.selected.value = doc['id']
            end
          rescue
            params.show_modal.call
          end
        end
      end
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
      MyForm(selected: @selected, show_modal: lambda{state.modal! true})
      MyList(selected: @selected, show_modal: lambda{state.modal! true})
      MyModal(ok: lambda {state.modal! false}) if state.modal
    end
  end
end