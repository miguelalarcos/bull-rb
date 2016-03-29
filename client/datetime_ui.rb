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
  end

  def render
    day = params.value || Time.now
    div do
      input(type: :text, value: day.strftime(params.format)).on(:click) {|event| state.show! !state.show}
      div(class: 'xdatetime-popover') do
        div(class: 'xdatetime-header') do
          span(class: 'minus-month'){'-'}.on(:click) {params.change_date.call day - 30*24*60*60}
          span{day.strftime('%m')}
          span(class: 'plus-month'){'+'}.on(:click) {params.change_date.call day + 30*24*60*60}
          span(class: 'minus-year'){'-'}.on(:click) {params.change_date.call day - 365*24*60*60}
          span{day.strftime('%Y')}
          span(class: 'plus-year'){'+'}.on(:click) {params.change_date.call day + 365*24*60*60}
        end
        6.times {|w| Week(week: w, day: day, change_date: params.change_date)}
        div(class: 'xdatetime-bottom') do
          span(class: 'minus-hour'){'-'}.on(:click) {params.change_date.call day - 60*60}
          span(class: 'plus-hour'){'+'}.on(:click) {params.change_date.call day + 60*60}
          span{day.strftime('%H:%M')}
          span(class: 'minus-minute'){'-'}.on(:click) {params.change_date.call day - 60}
          span(class: 'plus-minute'){'+'}.on(:click) {params.change_date.call day + 60}
        end if params.time
      end if state.show
    end
  end
end

