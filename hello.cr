def foo   
 "whooa"
end

spawn do
  c = "cat"   
  a = 1       
  b = 2
end

["one", "two", "three", "four"].each do |n|
  puts n
end

class Foo
  def bar
    true
  end
end

foo = Foo.new

debugger

foo.bar

puts "finished!"

