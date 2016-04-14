require_relative 'validation_core'
require 'set'

class ValidateCar
  include Validate

  def initialize skip: nil
    field 'registration' => String
    field 'color' => String
    field 'wheels' => Integer
    field 'date' => Time
    field 'auto' => String

    @skip = skip || []
  end

  def is_valid_registration? (value, doc)
    if doc[:wheels] <= 4
      value.start_with? 'A'
    else
      value.start_with? 'B'
    end
  end
end

