require 'reactive-ruby'

module MNotification
  def notifications
    MNotification.notifications
  end

  def self.notification_controller= controller
    @notifications = controller
  end

  def self.notifications
    @notifications
  end

  def notify_ok msg, level=10
    puts msg
    notifications.add ['ok', msg, level] if !notifications.nil?
  end

  def notify_error msg, level=10
    puts msg
    notifications.add ['error', msg, level] if !notifications.nil?
  end

  def notify_info msg, level=10
    puts msg
    notifications.add ['info', msg, level] if !notifications.nil?
  end
end

class NotificationController
  @@ticket = 0

  def initialize panel, level
    @panel = panel
    @level = level
  end

  def add msg
    return if msg[-1] < @level
    id = @@ticket
    @@ticket += 1
    @panel.append id, ['animated fadeIn'] + msg
    $window.after(4) do
      @panel.update id, ['animated fadeOut'] + msg
    end
    $window.after(5) do
      @panel.delete id
    end
  end
end

class Notification < React::Component::Base
  param :level

  before_mount do
    state.notifications! Hash.new
    MNotification.notification_controller = NotificationController.new self, params.level
  end

  def append id, row
    aux = state.notifications
    aux[id] = row
    state.notifications! aux
  end

  def update id, row
    aux = state.notifications
    aux[id] = row
    state.notifications! aux
  end

  def delete id
    aux = state.notifications
    aux.delete id
    state.notifications! aux
  end

  def render
    div(style: {position: 'absolute'}) do
      state.notifications.each_pair do |k, (animation, code, v, level)|
        div(key: k, class: animation + ' notification ' + code){v}
      end
    end
  end
end
