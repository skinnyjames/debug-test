require "socket"

Process.new("bin/crystal", ["i", "hello.cr"], shell: false, output: STDOUT, error: STDERR)

sleep 2

while msg = STDIN.gets
  TCPSocket.open("localhost", 4243) do |socket|
    puts "Connected"
    socket.sync = false
    socket << msg
    socket.flush
  end
end
