require 'reactive-ruby'
require 'time'

def day_row week, date
  ret = []
  ini_month = Time.new(date.year, date.month, 1, date.hour, date.min)
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
  param :change_date#, type: Proc

  def render
    span(class: params.data['decoration']){params.data['value']}.on(:click) do |event|
      params.change_date.call params.data['date']
    end
  end
end

class Week < React::Component::Base
  param :week
  param :day
  param :change_date#, type: Proc

  def render
    div(class: 'xdatetime-week') do
      day_row(params.week, params.day).each do |d|
        Day(data: d, change_date: params.change_date) # key?
      end
    end
  end
end

class DateTimeInput < React::Component::Base
  param :change_date #, type: Proc
  param :time
  param :value
  param :format, type: String

  before_mount do
    state.show! false
    state.day! Time.now
  end

  def render
    day = params.value || Time.now
    val = if params.value
            params.value.strftime(params.format)
          else
            ''
          end
    div do
      #input(type: :text, value: day.strftime(params.format)).on(:click) {|event| state.show! !state.show}
      input(type: :text, value: val).on(:click) {|event| state.show! !state.show}
      div(class: 'xdatetime-popover') do
        div(class: 'xdatetime-header') do
          i(class: 'minus-month fa fa-minus').on(:click) {state.day! state.day - 30*24*60*60} #{params.change_date.call day - 30*24*60*60}
          span{state.day.strftime('%m')}
          i(class: 'plus-month fa fa-plus').on(:click) {state.day! state.day  + 30*24*60*60}
          i(class: 'minus-year fa fa-minus').on(:click) {state.day! state.day  - 365*24*60*60}
          span{state.day.strftime('%Y')}
          i(class: 'plus-year fa fa-plus').on(:click) {state.day! state.day  + 365*24*60*60}
        end
        6.times {|w| Week(week: w, day: state.day, change_date: params.change_date)}
        div(class: 'xdatetime-bottom') do
          i(class: 'minus-hour fa fa-minus').on(:click) {params.change_date.call day - 60*60; state.day! state.day - 60*60}
          i(class: 'plus-hour fa fa-plus').on(:click) {params.change_date.call day + 60*60; state.day! state.day + 60*60}
          span{day.strftime('%H:%M')}
          i(class: 'minus-minute fa fa-minus').on(:click) {params.change_date.call day - 60; state.day! state.day - 60}
          i(class: 'plus-minute fa fa-plus').on(:click) {params.change_date.call day + 60; state.day! state.day + 60}
        end if params.time
      end if state.show
    end
  end
end

