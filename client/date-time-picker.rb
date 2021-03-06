require 'reactive-ruby'
require 'time'
require 'ui_common'

def day_row week, date, flag_time
  ret = []
  if flag_time
    ini_month = Time.new(date.year, date.month, 1, date.hour, date.min)
  else
    ini_month = Time.new(date.year, date.month, 1)
  end
  ini = ini_month - (ini_month.wday-1)*24*60*60
  ini = ini + 7*week*24*60*60
  end_ = ini + 7*24*60*60
  d = ini
  while d < end_
    if ini_month.month == d.month
      if d == Time.new
        decoration = 'xbold xunderline xtoday xdatetime-day'
      else
        decoration = 'xbold xdatetime-day'
      end
    else
      decoration = 'xcursive xdatetime-day'
    end
    ret << {value: d.strftime('%d'), date: d, decoration: decoration}
    d = d + 24*60*60
  end
  ret
end

class Day < React::Component::Base
  param :data
  param :on_change

  def render
    span(class: params.data['decoration']){params.data['value']}.on(:click) do |event|
      params.on_change.call params.data['date']
    end
  end
end

class Week < React::Component::Base
  param :week
  param :day
  param :time
  param :on_change

  def render
    div(class: 'xdatetime-week') do
      day_row(params.week, params.day, params.time).each do |d|
        Day(data: d, on_change: params.on_change) # key?
      end
    end
  end
end

class DateTimeInput < React::Component::Base
  param :on_change
  param :time
  param :value
  param :format, type: String
  param :valid
  param :dirty

  include ClassesInput

  before_mount do
    state.show! false
    state.day! Time.now
  end

  def on_change v
    if !params.time
      state.show! false
    end
    params.on_change.call v
  end

  def render
    day = params.value || Time.now
    val = if params.value
            params.value.strftime(params.format)
          else
            ''
          end
    span(class: 'date-time-box') do
      input(type: :text, value: val, disabled: 'disabled', class: valid_class + ' ' + dirty_class).on(:click) {|event| state.show! !state.show}
      div(class: 'xdatetime-popover') do
        div(class: 'xdatetime-header') do
          i(class: 'minus-month fa fa-minus').on(:click) {state.day! state.day - 30*24*60*60}
          span{state.day.strftime('%m')}
          i(class: 'plus-month fa fa-plus').on(:click) {state.day! state.day  + 30*24*60*60}
          i(class: 'minus-year fa fa-minus').on(:click) {state.day! state.day  - 365*24*60*60}
          #span{state.day.strftime('%Y')}
          input(placeholder: state.day.strftime('%Y'), autoFocus: true, class: 'year-input').on(:keyDown) do |event| # , value: state.day.strftime('%Y')
            if event.key_code == 13
              begin
                state.day! Time.new(Integer(event.target.value), state.day.month, state.day.day, state.day.hour, state.day.min)
              rescue
              end
            end
          end
          i(class: 'plus-year fa fa-plus').on(:click) {state.day! state.day  + 365*24*60*60}
        end
        6.times {|w| Week(week: w, day: state.day, time: params.time, on_change: lambda{|v| on_change v})}
        div(class: 'xdatetime-bottom') do
          i(class: 'minus-hour fa fa-minus').on(:click) {params.on_change.call day - 60*60; state.day! state.day - 60*60}
          i(class: 'plus-hour fa fa-plus').on(:click) {params.on_change.call day + 60*60; state.day! state.day + 60*60}
          span{day.strftime('%H:%M')}
          i(class: 'minus-minute fa fa-minus').on(:click) {params.on_change.call day - 60; state.day! state.day - 60}
          i(class: 'plus-minute fa fa-plus').on(:click) {params.on_change.call day + 60; state.day! state.day + 60}
        end if params.time
      end if state.show
    end
  end
end


