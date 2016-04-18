require 'ui_core'
require 'reactive-ruby'
require_relative 'reactive_var'
require 'bull-date-time-picker'
require 'bull-autocomplete'
require_relative 'validation/validation'
require_relative 'i18n'

class Menu < React::Component::Base
    param :change_page
    param :change_language
    param :logout
    param :active_page

    def active? page
        if page == params.active_page
            'button-active'
        else
            ''
        end
    end

    def render
        div(class: 'no-print') do
            ul(class: 'menu') do
                li(class: 'item-menu'){a(class: active?('pageA'), href: '#') {'page A'}.on(:click) {params.change_page.call 'pageA'}}
                li(class: 'item-menu'){a(class: active?('pageB'), href: '#') {'page B'}.on(:click) {params.change_page.call 'pageB'}}
                li(class: 'item-menu'){a(class: active?('OrderPage'), href: '#') {'order pag'}.on(:click) {params.change_page.call 'OrderPage'}}
            end
            a(href: '#') {' es '}.on(:click) {params.change_language.call 'es'}
            a(href: '#') {' en '}.on(:click) {params.change_language.call 'en'}
            a(href: '#', style: {float: 'right'}) {'logout'}.on(:click) do
                params.logout.call
            end
        end
    end
end

class PageA < React::Component::Base

    param :car_selected
    param :show_modal
    param :set_report_page

    def render
        div(class: 'no-print') do
            MyForm(selected: params.car_selected)
            hr
            DisplayCar(selected: params.car_selected)
            hr
            button(){'print car'}.on(:click) do
                $controller.rpc('print_car', params.car_selected.value).then do |report|
                    `document.getElementById("report").innerHTML = #{report}`
                end
                params.set_report_page.call
            end
            #button(type: :button){'show modal'}.on(:click) {params.show_modal.call}
        end
    end
end

class PageB < React::Component::Base
    param :car_selected
    param :i18n_map

    def render
        div(class: 'no-print') do
            div{i18n params.i18n_map, 'RED_CARS'}
            DisplayCars(color: 'red', selected: params.car_selected)
            hr
            div{i18n params.i18n_map, 'BLUE_CARS'}
            DisplayCars(color: 'blue', selected: params.car_selected)
        end
    end
end

class Order < React::Component::Base

    before_mount do
        @order_selected = RVar.new nil
        @line_selected = RVar.new nil
        state.order_exists! false
    end

    def render
        div do
            OrderForm(order_code: @order_selected, order_exists: lambda{|v| state.order_exists! v})
            OrderList(order_code: @order_selected, order_exists: lambda{|v| state.order_exists! v})
            div do
                LineForm(order_code: @order_selected.value, line_selected: @line_selected)
                OrderLines(order_code: @order_selected, line_selected: @line_selected)
            end if state.order_exists
        end
    end
end

class OrderList < DisplayList
    param :order_code
    param :order_exists

    before_mount do
        state.order_code! nil
        state.client_code! nil
        state.date! nil
        @client_code = RVar.new nil
        @order_date = RVar.new nil
        watch_ 'orders', params.order_code.value, @client_code.value, @order_date.value,
               [params.order_code, @client_code, @order_date]
    end

    def render
        div do
            div{'Order list'}
            div{'order code'}
            IntegerInput(change_attr: lambda{|v| state.order_code! v, value: state.order_code})
            hr
            ClientSearch(on_select: lambda{|v| state.client_code! v})
            hr
            div{'date of order'}
            DateTimeInput(change_attr: lambda{|v| state.date! v})
            button{'search'}.on(:click) do
                @order_code.value = state.order_code
                @client_code.value = state.client_code
                @order_date.value = state.date
            end
            state.docs.each do |doc|
                div(key: doc['id']){doc['code'] + ':' + doc['description']}.on(:click) do
                    params.order_code.value=doc['code']
                    params.order_exists.call true
                end
            end
        end
    end
end


class ClientSearch < React::Component::Base
    param :on_select
    #param :value

    before_mount do
        state.code! nil
        state.tmp_code! nil
        state.surname! nil
        state.clients! []
    end

    def render
        div do
            div{'Client Code:'}
            input(disabled: 'disabled', value: state.code).on(:click) {state.show! !state.show}
            div do
                IntegerInput(placeholder: 'code', change_attr: lambda{|v| state.tmp_code! v}, value: state.tmp_code)
                StringInput(placeholder: 'surname', change_attr: lambda{|v| state.surname! v}, value: state.surname)
                button{'search'}.on(:click) do
                    $controller.rpc('get_clients', state.tmp_code, state.surname).then do |clients|
                        state.clients! clients
                    end
                end
                state.clients.each do |cli|
                    div{cli['surname']}.on(:click){state.code! cli['code']; params.on_select.call cli['code']}
                end
            end if state.show
        end
    end
end

class OrderForm < Form
    @@table = 'order'
    param :order_code
    param :order_exists

    before_mount do
        get params.order_code
    end

    def clear
        state.code! nil
        state.description! ''
        state.client_code! nil
        state.date! nil
    end

    def render
        div do
            div{'Order form'}
            div{state.code}
            button{'new order'}.on(:click) do
                $controller.rpc('get_ticket').then do |code|
                    clear
                    state.code! code
                    #params.order_code.value = code
                    params.order_exists.call false
                end
            end
            hr
            ClientSearch(on_select: change_attr('client_code'))
            hr
            div('Date:')
            DateTimeInput(change_attr: change_attr('date'), format: '%d-%m-%Y %H:%M')
            div{'Description:'}
            StringInput(value: state.description, change_attr: change_attr('description'))
            button{'save'}.on(:click) do
                save
                params.order_exists.call true
            end
        end
    end
end

class LineForm < Form
    @@table = 'line'
    @@constants = ['order_code']
    param :order_code
    param :line_selected

    before_mount do
        get params.line_selected
    end

    def clear
        state.product! nil
        state.quantity! nil
        state.price! nil
    end

    def render
        div do
            div{'Line form'}
            div{'Product'}
            StringInput(change_attr: change_attr('product'), value: state.product)
            div{'Quantity'}
            IntegerInput(change_attr: change_attr('quantity'), value: state.quantity)
            div{'Price'}
            FloatInput(change_attr: change_attr('price'), value: state.price)
            button{ 'save' }.on(:click) {save; clear} #if state.is_valid
            button{'clear'}.on(:click){clear}
        end
    end
end

class OrderLines < DisplayList
    param :line_selected
    param :order_code

    before_mount do
        watch_ 'lines_of_order', params.order_code.value, [params.order_code]
    end

    def render
        total = state.docs.inject(0){|sum, doc| sum + doc['price']}
        div do
            div{'Order lines'}
            state.docs.each do |doc|
                div(key: doc['id']) do
                    tr do
                        td{doc['product']}
                        td{doc['quantity']}
                        td{doc['price']}
                        td{'Edit'}.on(:click) do
                            params.line_selected.value = doc['id']
                        end
                    end
                end
            end
            span{"Total: #{total} €"}
        end
    end
end

class OrderPage < React::Component::Base
    def render
        Order()
    end
end

class Report < React::Component::Base
    def render
        div do
            i(class: "fa fa-print no-print fa-5x", style: {position: 'absolute'}).on(:click) {`window.print()`}
            div(id: 'report')
        end
    end
end

class Login < React::Component::Base
    param :set_user

    before_mount do
        state.user_name! ''
        state.password! ''
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
        end
    end
end

class MyModal < React::Component::Base
    include Modal
    param :ok

    def content
        div do
            h1{'Hello!'}
            button(type: :button){'close'}.on(:click) {params.ok.call}
        end
    end
end

class App < React::Component::Base

    before_mount do
        state.create_user! false
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
            OrderPage()
=begin
            if state.user
                Notification(level: 0)
                Menu(logout: lambda{state.user! false; $controller.logout}, change_page: lambda{|v| state.page! v},
                     change_language: lambda{|v| @language.value = v}, active_page: state.page)
                PageA(set_report_page: lambda {state.page! 'report'},car_selected: @car_selected,
                      show_modal: lambda{state.modal! true}) if state.page == 'pageA'
                PageB(car_selected: @car_selected, i18n_map: state.i18n_map) if state.page == 'pageB'
                OrderPage() if state.page == 'OrderPage'
                Report() if state.page == 'report'
                MyModal(ok: lambda {state.modal! false}) if state.modal
            else
                Login(set_user: lambda{|v| state.user! v})
                #CreateUserTextCaptcha(set_user: lambda{|v| state.user! v})
                a(href: '#'){'I want to create an user!'}.on(:click) {state.create_user! true} if !state.create_user
                CreateUserNetCaptcha(set_user: lambda{|v| state.user! v}) if state.create_user
            end
=end
        end
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
        div{"The car with registration #{state.registration} is color #{state.color}"}
    end
end

class MyForm < Form

    @@table = 'car'
    param :selected

    before_mount do
        #@fields_ref = ['auto']
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
        state.auto! ''
    end

    def render
        ValidateCar.new.validate state
        div do
            div{state.id}
            span{'Registration'}
            #input(class: valid_class state.is_valid_registration, value: state.registration).on(:click) {|e| state.registration! e.target.value}
            StringInput(is_valid: state.is_valid_registration, change_attr: change_attr('registration'), value: state.registration)
            div(class: 'red'){'not valid registration'} if !state.is_valid_registration
            span{'Wheels'}
            IntegerInput(is_valid: state.is_valid_wheels, key: 'my_key', change_attr: change_attr('wheels'), value: state.wheels)
            span{'Color'}
            SelectInput(change_attr: change_attr('color'), value: state.color, options: ['red', 'blue'])
            span{'Date'}
            DateTimeInput(change_date: change_attr('date'), format: '%d-%m-%Y %H:%M', value: state.date, time: true)
            span{'Nested'}
            FloatInput(is_valid: state.is_valid_nested_x, key: 'my_key2', change_attr: change_attr('nested.x'), value: state.nested['x'])
            span{'Autocomplete'}
            AutocompleteInput(change_attr: change_attr('auto'), ref_: 'location', #set_validation: lambda{|v| puts v; state.is_valid_auto! v},
                              name: 'description', value: state.auto)
            button(type: :button) { 'save' }.on(:click) {save} if (state.is_valid && state.is_valid_auto)
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

