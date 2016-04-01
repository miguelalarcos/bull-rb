require 'rspec'
require_relative '../validation/validation'

class ValidateA
  include Validate

  def initialize
    field 'a' => String
    field 'b' => Integer
  end

  def is_valid_a? (value, doc)
    if doc['b'] <= 4
      value.start_with? 'A'
    else
      value.start_with? 'B'
    end
  end

  def is_valid_b? (value, doc)
    !value.nil?
  end
end

RSpec.describe Validate do

  it 'test_validate insert full document ok' do
    bool1 = ValidateA.new.validate_server_side 'a' => 'A', 'b' => 4
    expect(bool1).to be_truthy
  end

  it 'test_validate insert full document fail' do
    bool1 = ValidateA.new.validate_server_side 'a' => 'A', 'b' => 5
    expect(bool1).to be_falsey
  end

  it 'test_validate insert partial document' do
    expect {ValidateA.new.validate_server_side 'a' => 'A' }.to raise_error(NoMethodError)
  end
end