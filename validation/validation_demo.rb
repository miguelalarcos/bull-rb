require_relative 'validation_core'

class ValidateDemo
  include Validate

  def initialize
    field 'string_a' => String
    field 'password' => String
    field 'integer_x' => Integer
    field 'nested_float_y.value' => Numeric #Float
    field 'observations' => String
  end

  def valid_string_a? (value, doc)
    value.start_with? 'A'
  end

  def valid_integer_x? (value, doc)
    value > 10
  end

  def valid_nested_float_y_value?(value, doc)
    value < 0.0
  end

end

