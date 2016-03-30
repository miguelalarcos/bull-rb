require_relative 'ui_core'
require 'reactive-ruby'
require_relative 'reactive_var'
require_relative 'datetime_ui'
require_relative '../validation/validation'

class App < React::Component::Base

    before_mount do
        @car_selected = RVar.new 0
        state.date! Time.now
    end

    def render
        div do
            MyForm(selected: @car_selected)
            hr
            DisplayCar(selected: @car_selected)
            hr
            div{'red cars:'}
            DisplayCars(color: 'red', selected: @car_selected)
            hr
            div{'blue cars:'}
            DisplayCars(color: 'blue', selected: @car_selected)
        end
    end    
end

class DisplayCar < DisplayDoc
    @@table = 'car'
    param :selected

    before_mount do
        reactive(params.selected) do
            watch_ params.selected.value
        end
    end

    def clear
        state.registration! ''
        state.color! ''
    end

    def render
        div do
            b {state.registration}
        end
    end
end

class MyForm < Form

    @@table = 'car'
    param :selected

    before_mount do
        reactive(params.selected) do
            get params.selected.value
        end
    end

    def clear
        state.registration! ''
        state.color! ''
        state.wheels! 0
        state.date! nil
        state.id! nil
    end

    def render
        ValidateCar.new.validate state
        div do
            StringInput(change_attr: change_attr('registration'), value: state.registration)
            span{'not valid registration'} if !state.is_valid_registration
            IntegerInput(change_attr: change_attr('wheels'), value: state.wheels)
            DateTimeInput(change_date: change_attr('date'), format: '%d-%m-%Y %H:%M', value: state.date, time: true)
            button(type: :button) { 'save' }.on(:click) {save} if state.is_valid
            button(type: :button) { 'clear' }.on(:click) {clear}
        end        
    end
end

class DisplayCars < DisplayList
    param :color
    param :selected

    before_mount do
        watch_ 'cars_of_color', params.color
    end

    def render
        div do
            state.docs.each do |doc|
                div(key: doc['id']) do
                    span{doc['registration']}
                    button(type: :button) {'select'}.on(:click) do
                        params.selected.value = doc['id']
                    end
                    button(type: :button) {'change color'}.on(:click) do
                        color = 'red'
                        if doc['color'] == 'red'
                            color = 'blue'
                        end
                        $controller.rpc('update', 'car', doc['id'], {color: color})
                    end
                end
            end
        end
    end
end

