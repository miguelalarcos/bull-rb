require 'reactive-ruby'
require 'ui_common'

class AutocompleteInput < React::Component::Base

  param :value
  param :on_change
  param :rmethod
  #param :name
  param :valid
  param :dirty

  include ClassesInput

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
    span(class: 'autocomplete-box') do
      input(type: :text, value: params.value, class: valid_class + ' ' + dirty_class).on(:change) do |event|
        params.on_change.call event.target.value
        $controller.rpc(params.rmethod, event.target.value).then do |result|
          state.options! result #result.map {|x| x[params.name]}
        end
      end.on(:keyDown) do |event|
        if event.key_code == 13
          params.on_change.call state.options[state.index]
          state.options! []
        elsif event.key_code == 40
          state.index! (state.index + 1) % state.options.length if state.options.length != 0
        elsif event.key_code == 38
          state.index! (state.index - 1) % state.options.length if state.options.length != 0
        end
      end
      div(class: 'autocomplete-popover') do
        state.options.each_with_index do |v, i|
          r = Regexp.new("(.*)(#{params.value})(.*)", true)
          m = v.match(r)
          div(class: selected(i)) do
            span{m[1]}
            b{m[2]}
            span{m[3]}
          end.on(:click) do |e|
            params.on_change.call v
            state.options! []
          end if m
        end
      end if state.options.length > 1 || state.options[0] != params.value
    end
  end
end

