require 'rspec'
require_relative '../lib/utils'

RSpec.describe '' do
  it 'set simple' do
    ret = {}
    set_nested('a', 5, {}){|root, value| ret[root] = value}
    doc = {'a' => 5}
    expect(ret).to eq doc
  end

  it 'set nested' do
    ret = {}
    set_nested('a.b', 5, {}){|root, value| ret[root] = value}
    doc = {'a' => {'b' => 5}}
    expect(ret).to eq doc
  end

  it 'set nested with existing values' do
    ret = {}
    set_nested('a.b.x', 5, {'a'=>{'b'=>{'z'=>6}, 'c'=>7}}){|root, value| ret[root] = value}
    doc = {'a' => {'b' => {'x'=> 5, 'z'=>6 }, 'c' => 7}}
    expect(ret).to eq doc
  end

  it 'get simple' do
    ret = get_nested!({}, 'a') do
      #d = Hash.new
      #d['a'] = 8
      #d
      8
    end
    doc = {'a'=> 8}
    expect(ret).to eq doc
  end

  it 'get nested' do
    ret = get_nested!({}, 'a.b') do
      #d = Hash.new
      #d['a'] = {'b' => 5, 'c' => 7}
      #d
      {'b' => 5, 'c' => 7}
    end
    doc = {'a'=> {'b' => 5}}
    expect(ret).to eq doc
  end

  it 'get nested with existing values' do
    ret = get_nested!({'x' => 'x', 'a'=>{'d'=>8}}, 'a.b') do
      #d = Hash.new
      #d['a'] = {'b' => 5, 'c' => 7}
      #d
      {'b' => 5, 'c' => 7}
    end
    doc = {'x'=>'x', 'a'=> {'b' => 5, 'd'=>8}}
    expect(ret).to eq doc
  end

end