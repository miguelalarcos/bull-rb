require_relative 'validation_core'
require 'set'

class ValidateCar
  include Validate

  def initialize refs: nil #, conn: nil
    field 'registration' => String
    field 'color' => String
    field 'wheels' => Integer
    field 'date' => Time
    field 'auto' => String

    @refs = refs
    #@conn = conn
  end

  def is_valid_registration? (value, doc)
    if doc[:wheels] <= 4
      value.start_with? 'A'
    else
      value.start_with? 'B'
    end
  end

  def is_valid_auto? (value, doc)
    #is_value_in_refs?(attr: 'auto', ref: 'location', name: 'description', value: value)
    is_value_in_refs?('auto')
  end
end

