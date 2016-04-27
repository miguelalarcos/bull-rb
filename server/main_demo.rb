require './server'
require '../validation/validation_demo'

class AppController < BullServerController

  def before_insert_demo doc
    ValidateDemo.new.validate doc
  end

  def before_update_demo old, new, merged
    ValidateDemo.new.validate merged
  end

end

