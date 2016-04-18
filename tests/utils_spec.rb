require 'rspec'
require_relative '../lib/utils'

RSpec.describe '' do
  it 'set simple' do
    ret = {}
    set_nested_state('a', 5, {}){|root, value| ret[root] = value}
    doc = {'a' => 5}
    expect(ret).to eq doc
  end

  it 'set nested' do
    ret = {}
    set_nested_state('a.b', 5, {}){|root, value| ret[root] = value}
    doc = {'a' => {'b' => 5}}
    expect(ret).to eq doc
  end

  it 'set nested with existing values' do
    ret = {}
    set_nested_state('a.b', 5, {'a'=>{'c'=>7}}){|root, value| ret[root] = value}
    doc = {'a' => {'b' => 5, 'c' => 7}}
    expect(ret).to eq doc
  end

  it 'get simple' do
    ret = get_nested!({}, 'a') do
      d = Hash.new
      d['a'] = 8
      d
    end
    doc = {'a'=> 8}
    expect(ret).to eq doc
  end

  it 'get nested' do
    ret = get_nested!({}, 'a.b') do
      d = Hash.new
      d['a'] = {'b' => 5, 'c' => 7}
      d
    end
    doc = {'a'=> {'b' => 5}}
    expect(ret).to eq doc
  end

  it 'get nested with existing values' do
    ret = get_nested!({'x' => 'x'}, 'a.b') do
      d = Hash.new
      d['a'] = {'b' => 5, 'c' => 7}
      d
    end
    doc = {'x'=>'x', 'a'=> {'b' => 5}}
    expect(ret).to eq doc
  end

end