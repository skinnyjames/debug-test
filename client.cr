require "socket"


UNIXSocket.open("debug.sock") do |socket|
  puts "Connected"
  while msg = STDIN.gets
    puts "PROXYING #{msg.strip} to socket"
    socket << msg
    puts socket.gets
  end
end
