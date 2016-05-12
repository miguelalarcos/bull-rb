require 'eventmachine'
require 'fiber'
require 'rethinkdb'

$r = RethinkDB::RQL.new
$conn = $r.connect()

def f parent
  $r.table('aux').em_run($conn) do |doc|
    yield doc
    #parent.transfer doc
  end
  puts "\n***\n"
end

def g parent
  count = 0
  f(parent) do |doc|
    print doc
    count += 1
    yield if count == 3
  end
  print 'fin2'
end

helper = Fiber.new do |parent|
  g(parent) do
    print 'fin'
    parent.transfer 7
    puts 'END'
  end
end

EM.run do
  h = Fiber.new do
    i = helper.transfer Fiber.current
    print i
    i=i+1
    puts 'yahoo', i
  end
  h.transfer
  puts 'google'
  #EM.stop
end

