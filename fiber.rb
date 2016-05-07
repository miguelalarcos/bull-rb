require 'eventmachine'
require 'fiber'
require 'rethinkdb'
require 'em-synchrony'

$r = RethinkDB::RQL.new
$conn = $r.connect()

def get_array predicate
  ret = []
  docs_with_count(predicate) do |count, row|
    ret << row
    yield ret if ret.length == count
  end
end

def docs_with_count predicate
  predicate.count().em_run($conn) do |count|
    predicate.em_run($conn) do |doc|
      yield count, doc
    end
  end
end

def rsync pred
  aux = Fiber.new do |current|
    pred.em_run($conn) do |doc|
      current.transfer doc
    end
  end
  aux.transfer Fiber.current
end

def rmsync pred
  aux = Fiber.new do |current|
    get_array(pred){|docs| current.transfer docs}
  end
  aux.transfer Fiber.current
end

fib = Fiber.new do
  puts 'inside fiber'
  doc = rsync $r.table('aux').get('94fcf756-ae81-4eb6-a50e-4004717c948a')
  print doc
  puts
  docs = rmsync $r.table('aux')
  print docs
  puts
  EM.stop
end

EM.run do
  fib.resume
  puts 'yahoo'
end

