require 'reactive-ruby'

class AutocompleteInput < React::Component::Base

  param :value
  param :change_attr
  param :add_ref
  param :ref_
  param :name

  before_mount do
    state.options! []
  end

  def render
    div do
      input(type: :text, value: params.value).on(:change) do |event|
        params.change_attr.call event.target.value
        params.add_ref.call([params.ref_, params.name, event.target.value]) if state.options.include? event.target.value
        $controller.rpc('get_' + params.ref_, event.target.value).then do |result|
          result = result.map do |x|
            x[params.name]
          end
          #result = result.select {|k, v| k == params.name}.values
          state.options! result
        end
      end
      div(style: {backgroundColor: 'white', position: 'absolute', cursor: 'pointer'}) do
        state.options.each do |v|
          div{v}.on(:click) do |e|
            params.change_attr.call v
            params.add_ref.call([params.ref_, params.name, v])
            state.options! []
          end
        end
      end if state.options.length > 1 || state.options[0] != params.value
    end
  end
end