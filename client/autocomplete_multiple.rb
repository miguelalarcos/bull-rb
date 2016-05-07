require 'reactive-ruby'
require 'autocomplete'
require 'ui_common'

class AutocompleteMultipleInput < React::Component::Base

  param :value
  param :on_change, type: Proc
  param :rmethod
  param :valid
  param :dirty

  include ClassesInput

  before_mount do

  end

  def on_change v
    list = params.value.dup
    list << v if !list.include? v
    params.on_change list
  end

  def render
    span do
      AutocompleteInput(rmethod: rmethod, value: params.value, on_change: lambda{|v| on_change v}, dirty: params.dirty)
      params.value.each do |v|
        span(class: 'auto-multiple') do
          span{v}
          span{i(class: 'fa fa-times')}.on(:click) do
            list = params.value.dup
            list.delete v
            params.on_change list
          end
        end
      end
    end
  end
end
