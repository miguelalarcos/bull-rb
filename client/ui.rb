require_relative 'ui_core'
require 'reactive-ruby'
require_relative 'reactive_var'

class Validate_Car
    def self.is_valid_registration?(value)
        value.start_with? 'A'
    end
end

class App < React::Component::Base

    before_mount do
        @car_selected = RVar.new 0
    end

    def render
        div do
            MyForm(selected: @car_selected)
            br
            DisplayCar(selected: @car_selected)
        end
    end    
end

class DisplayCar < DisplayDoc

    param :selected

    before_mount do
        state.registration! ''
        watch_ 'car', params.selected
    end

    def render
        div do
            span {"display_car"}
            b {state.registration}
        end
    end
end

class MyForm < Form
    @@table = 'car'   

    param :selected

    before_mount do
        state.registration! ''
        get params.selected
    end

    def render
        v1 = Validate_Car.is_valid_registration? state.registration
        state.is_valid_registration! v1
        state.is_valid! [v1].all?        
        div do
            AttrInput(change_attr: change_attr('registration'), value: state.registration)
            span{'not valid registration'} if !state.is_valid_registration
            button(type: :button) { "update" }.on(:click) {update} if state.is_valid
        end        
    end
end
