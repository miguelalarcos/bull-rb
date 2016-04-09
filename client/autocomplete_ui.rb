require 'reactive-ruby'

class AutocompleteInput < React::Component::Base

  param :value
  param :change_attr
  param :add_ref
  param :ref_
  param :name

  before_mount do
    state.options! []
    state.index! 0
  end

  def selected pos
    if pos == state.index
      'autocomplete-selected'
    else
      ''
    end
  end

  def render
    div do
      input(type: :text, value: params.value).on(:change) do |event|
        params.change_attr.call event.target.value
        if state.options.include? event.target.value
          params.add_ref.call true
        else
          params.add_ref.call false
        end
        $controller.rpc('get_' + params.ref_, event.target.value).then do |result|
          state.options! result.map {|x| x[params.name]}
        end
      end.on(:keyDown) do |event|
        if event.key_code == 13
          params.change_attr.call state.options[state.index]
          params.add_ref.call true
          state.options! []
        elsif event.key_code == 40
          state.index! (state.index + 1) % state.options.length if state.options.length != 0
        elsif event.key_code == 38
          state.index! (state.index - 1) % state.options.length if state.options.length != 0
        end
      end
      div(class: 'autocomplete-popover') do
        state.options.each_with_index do |v, i|
          div(class: selected(i)){v}.on(:click) do |e|
            params.change_attr.call v
            params.add_ref.call true
            state.options! []
          end
        end
      end if state.options.length > 1 || state.options[0] != params.value
    end
  end
end