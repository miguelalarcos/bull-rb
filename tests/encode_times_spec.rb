require 'rspec'
require_relative '../lib/encode_times'
require_relative '../lib/symbolize'
require 'json'

RSpec.describe '' do
  it 'encode times' do
    msg = {:a => Time.now, :b => {:c => 1, :d => Time.now}, :r => [1,2,Time.now]}
    ret = encode_times msg, ''
    expect(ret).to eq ['a', 'b.d', 'r.2']
  end
end

RSpec.describe '' do
  it 'decode times' do
    msg = {:a => Time.now, :b => {:c => 1, :d => Time.now}, :r => [1,2,Time.now]}
    keys = encode_times msg, ''
    msg = msg.to_json
    msg = JSON.parse msg
    msg = symbolize_keys msg

    resolve_times msg, keys
    doc = msg

    expect(doc[:a]).to be_a Time
    expect(doc[:b][:d]).to be_a Time
    expect(doc[:r][2]).to be_a Time
    expect(doc[:r][1]).not_to be_a Time
  end
end