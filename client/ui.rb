require 'ui_core'
require 'reactive-ruby'
require_relative 'reactive_var'
require_relative 'datetime_ui'
require_relative 'autocomplete_ui'
require_relative 'validation/validation'
require_relative 'i18n'

class Menu < React::Component::Base
    param :change_page
    param :change_language
    param :logout

    def render
        div do
            button(type: :button, class: 'button-secondary pure-button'){'logout'}.on(:click) do
                params.logout.call
                $controller.logout
            end
            div(class: 'pure-menu pure-menu-horizontal') do
                ul(class: 'pure-menu-list') do
                    li(class: 'pure-menu-item') do
                        a(class: 'pure-menu-link', href: '#') {'page A'}.on(:click) {params.change_page.call 'pageA'}
                    end
                    li(class: 'pure-menu-item') do
                        a(class: 'pure-menu-link', href: '#') {'page B'}.on(:click) {params.change_page.call 'pageB'}
                    end
                end
                a(class: 'pure-menu-link', href: '#') {'es'}.on(:click) {params.change_language.call 'es'}
                a(class: 'pure-menu-link', href: '#') {'en'}.on(:click) {params.change_language.call 'en'}
            end
        end
    end
end

class PageA < React::Component::Base

    param :car_selected
    param :show_modal

    def render
        div do
            MyForm(selected: params.car_selected)
            hr
            DisplayCar(selected: params.car_selected)
            hr
            button(type: :button){'show modal'}.on(:click) {params.show_modal.call}
        end
    end
end

class PageB < React::Component::Base
    param :car_selected
    param :i18n_map

    def render
        div do
            div{i18n params.i18n_map, 'RED_CARS'}
            DisplayCars(color: 'red', selected: params.car_selected)
            hr
            div{i18n params.i18n_map, 'BLUE_CARS'}
            DisplayCars(color: 'blue', selected: params.car_selected)
        end
    end
end

class Login < React::Component::Base
    param :set_user

    before_mount do
        state.user_name! ''
        state.password! ''
        state.create_user_name! ''
        state.create_password! ''
    end

    def render
        div do
            StringInput(change_attr: lambda {|v| state.user_name! v}, value: state.user_name)
            PasswordInput(change_attr: lambda {|v| state.password! v}, value: state.password)
            button(type: :button) { 'login' }.on(:click) do
                $controller.rpc('login', state.user_name, state.password).then do |response|
                    params.set_user.call response
                end
            end
            div {'Create user'}
            StringInput(change_attr: lambda {|v| state.create_user_name! v}, value: state.create_user_name)
            PasswordInput(change_attr: lambda {|v| state.create_password! v}, value: state.create_password)
            button(type: :button) { 'create' }.on(:click) do
                $controller.rpc('create_user', state.create_user_name, state.create_password).then do |response|
                    puts response
                end
            end
        end
    end
end

class Modal < React::Component::Base
    param :ok

    def render
        div(class: 'modal') do
            div(class: 'modal-center') do
                h1{'Hello!'}
                button(type: :button){'close'}.on(:click) {params.ok.call}
            end
        end
    end
end

class App < React::Component::Base

    before_mount do
        state.modal! false
        state.user! false
        state.page! 'pageA'
        @car_selected = RVar.new 0
        @language = RVar.new 'es'
        reactive(@language) do
            $controller.rpc('get_i18n', @language.value).then do|response|
                state.i18n_map! response
            end
        end
    end

    def render
        div do
            Notification(level: 0)
            Menu(logout: lambda{state.user! false}, change_page: lambda{|v| state.page! v}, change_language: lambda{|v| @language.value = v})
            PageA(car_selected: @car_selected, show_modal: lambda{state.modal! true}) if state.page == 'pageA'
            PageB(car_selected: @car_selected, i18n_map: state.i18n_map) if state.page == 'pageB'
            Modal(ok: lambda {state.modal! false}) if state.modal
        end
        #if state.user
        #    Page()
        #else
        #    Login(set_user: lambda {|v| state.user! v})
        #end
    end    
end

class DisplayCar < DisplayDoc
    @@table = 'car'
    param :selected

    before_mount do
        watch_ params.selected
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
        @fields_ref = {'auto'=>['location', 'description']}
        get params.selected
    end

    def clear
        state.registration! ''
        state.color! ''
        state.wheels! nil
        state.date! nil
        state.id! nil
        d = {'x' => nil}
        state.nested! d
        state.auto = nil
    end

    def render
        ValidateCar.new(refs: @refs).validate state
        div do
            div{state.id}
            span{'Registration'}
            StringInput(change_attr: change_attr('registration'), value: state.registration)
            span{'not valid registration'} if !state.is_valid_registration
            span{'Wheels'}
            IntegerInput(key: 'my_key', change_attr: change_attr('wheels'), value: state.wheels)
            span{'Color'}
            StringInput(change_attr: change_attr('color'), value: state.color)
            span{'Date'}
            DateTimeInput(change_date: change_attr('date'), format: '%d-%m-%Y %H:%M', value: state.date, time: true)
            span{'Nested'}
            IntegerInput(key: 'my_key2', change_attr: change_attr('nested.x'), value: state.nested['x'])
            span{'Autocomplete'}
            AutocompleteInput(change_attr: change_attr('auto'), ref_: 'location', add_ref: add_ref,
                              name: 'description', value: state.auto)
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
                        $controller.update('car', doc['id'], {color: color})
                    end
                end
            end
        end
    end
end

