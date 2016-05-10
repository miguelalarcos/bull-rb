require 'promise'

def f
  v = Promise.new
  v.resolve 5
  v.then do |r|
    puts r
    7
  end
end

def g
  f.then do |x|
    puts x
  end
end

g



