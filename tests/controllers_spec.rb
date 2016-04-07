$LOAD_PATH.unshift '.'
$LOAD_PATH.unshift 'lib'
print $LOAD_PATH
LIBS_TO_SKIP = ['browser', 'browser/socket', 'browser/delay', 'promise']

module Kernel
  alias :old_require :require
  def require(path)
    if path == 'promise'
      old_require('tests/promise')
    else
      old_require(path) unless LIBS_TO_SKIP.include?(path)
    end
  end
end

require 'rspec'
require 'rspec/mocks'
require 'json'
require_relative '../client/client'
require_relative '../lib/encode_times'

RSpec.describe '' do

  before(:each) do
    @client_controller = Controller.new
    @socket = double('socket')
    @client_controller.ws = @socket
    allow(@socket).to receive(:send)
  end

  it 'insert' do
    expect(@socket).to receive(:send).with('{"command":"rpc_insert","id":0,"args":["car"],"kwargs":{"value":{"a":5}},"times":[]}')
    @client_controller.insert('car', {a:5})
  end

  it 'update' do
    expect(@socket).to receive(:send).with('{"command":"rpc_update","id":1,"args":["car",0],"kwargs":{"value":{"a":5}},"times":[]}')
    @client_controller.update('car', 0, {a:5})
  end

end