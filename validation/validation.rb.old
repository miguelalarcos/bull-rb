require_relative 'validation_core'
require 'set'

class ValidateCar
  include Validate

  def initialize
    field 'registration' => String
    field 'color' => String
    field 'wheels' => Integer
    field 'date' => Time
    field 'auto' => String
    field 'nested' => Hash
    field 'nested.x' => Float
  end

  def valid_registration? (value, doc)
    if doc[:wheels] <= 4
      value.start_with? 'A'
    else
      value.start_with? 'B'
    end
  end
end

