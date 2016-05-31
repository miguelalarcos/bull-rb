require 'eventmachine'
require 'fiber'
require 'rethinkdb'

$r = RethinkDB::RQL.new
$conn = $r.connect()

def f parent
  $r.table('aux').em_run($conn) do |doc|
    yield doc
    #parent.transfer doc
    puts '+++', Fiber.current
  end
  puts "\n***\n"
end

def g parent
  count = 0
  f(parent) do |doc|
    print doc
    count += 1
    yield if count == 1
    puts '+'
  end
  print 'fin2'
end

helper = Fiber.new do |parent|
  puts Fiber.current
  g(parent) do
    print 'fin', Fiber.current
    x=parent.transfer 7
    puts 'END',x
  end
  puts '-fin helper fiber'
end

EM.run do
  puts Fiber.current
  root = Fiber.current
  h = Fiber.new do
    puts Fiber.current
    fb = Fiber.current
    g nil do
      print 'fin', Fiber.current
      x=fb.transfer 7
      puts 'END',x
    end
    i=root.transfer
    print i
    i=i+1
    puts 'yahoo', i
    100
    #i = helper.transfer Fiber.current
    #print i
    #i=i+1
    #puts 'yahoo', i
    #100
  end
  h.transfer
  puts 'google'
  #EM.stop
end

