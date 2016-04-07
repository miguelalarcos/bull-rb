require 'rspec'
require_relative '../validation/validation'

class ValidateA
  include Validate

  def initialize
    field 'a' => String
    field 'b' => Integer
    field 'c' => Hash
    field 'c.x' => Integer
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

  it 'test_validate insert document ok' do
    bool1 = ValidateA.new.validate 'a' => 'A', 'b' => 4
    expect(bool1).to be_truthy
  end

  it 'test_validate insert full document fail' do
    bool1 = ValidateA.new.validate 'a' => 'A', 'b' => 5
    expect(bool1).to be_falsey
  end

  it 'test_validate insert partial document' do
    expect(ValidateA.new.validate 'a' => 'A').to be_falsey
  end

  it 'test_validate insert document nested' do
    bool1 = ValidateA.new.validate 'a' => 'A', 'b' => 4, 'c' => {'x' => 1}
    expect(bool1).to be_truthy
  end

  it 'test validate_ (client side) ok' do
    ret = {}
    ValidateA.new.validate_('a' => 'A', 'b' => 4) do |k, v|
      ret[k] = v
    end
    d = {'a'=>true, 'b'=>true, 'c' => true, 'c_x'=>true}
    expect(ret).to eq d
  end

  it 'test validate_ (client side) full document ok' do
    ret = {}
    ValidateA.new.validate_('a' => 'A', 'b' => 4, 'c'=>{'x'=>1}) do |k, v|
      ret[k] = v
    end
    d = {'a'=>true, 'b'=>true, 'c' => true, 'c_x'=>true}
    expect(ret).to eq d
  end

  it 'test validate_ (client side) full document fail' do
    ret = {}
    ValidateA.new.validate_('a' => 'A', 'b' => 4, 'c'=>{'x'=>'1'}) do |k, v|
      ret[k] = v
    end
    d = {'a'=>true, 'b'=>true, 'c' => true, 'c_x'=>false}
    expect(ret).to eq d
  end

end