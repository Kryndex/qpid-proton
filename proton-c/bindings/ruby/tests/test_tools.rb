# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.


# Tools for tests. Only minitest is used.

require 'minitest/autorun'
require 'qpid_proton'
require 'thread'
require 'socket'

Container = Qpid::Proton::Container
ListenHandler = Qpid::Proton::Listener::Handler
MessagingHandler = Qpid::Proton::Handler::MessagingHandler

class TestError < Exception; end

def wait_port(port, timeout=5)
  deadline = Time.now + timeout
  begin  # Wait for the port to be connectible
    TCPSocket.open("", $port).close
  rescue Errno::ECONNREFUSED
    if Time.now > deadline then
      raise TestError, "timed out waiting for port #{port}"
    end
    sleep(0.1)
    retry
  end
end

# Handler that records some common events that are checked by tests
class TestHandler < MessagingHandler
  attr_reader :errors, :connections, :sessions, :links, :messages

  # Pass optional extra handlers and options to the Container
  # @param raise_errors if true raise an exception for error events, if false, store them in #errors
  def initialize(raise_errors=true)
    super()
    @raise_errors = raise_errors
    @errors, @connections, @sessions, @links, @messages = 5.times.collect { [] }
  end

  # If the handler has errors, raise a TestError with all the error text
  def raise_errors()
    return if @errors.empty?
    text = ""
    while @errors.size > 0
      text << @errors.pop + "\n"
    end
    raise TestError.new("TestHandler has errors:\n #{text}")
  end

  def on_error(event)
    @errors.push "#{event.type}: #{event.condition.inspect}"
    raise_errors if @raise_errors
  end

  def endpoint_opened(queue, endpoint)
    queue.push(endpoint)
  end

  def on_connection_opened(event)
    endpoint_opened(@connections, event.connection)
  end

  def on_session_opened(event)
    endpoint_opened(@sessions, event.session)
  end

  def on_link_opened(event)
    endpoint_opened(@links, event.link)
  end

  def on_message(event)
    @messages.push(event.message)
  end
end

# ListenHandler that closes the Listener after first accept
class ListenOnceHandler < ListenHandler
  def on_error(l, e)  raise TestError, e.inspect; end
  def on_accept(l) l.close; super; end
end

# A client/server pair of ConnectionDrivers linked by a socket pair
class DriverPair < Array

  def initialize(client_handler, server_handler)
    handlers = [client_handler, server_handler]
    self[0..-1] = Socket.pair(:LOCAL, :STREAM, 0).map { |s| HandlerDriver.new(s, handlers.shift) }
    server.transport.set_server
  end

  alias client first
  alias server last

  # Run till there is nothing to do
  def run
    begin
      each { |d| d.process }
    end while (IO.select(self, [], [], 0) rescue nil)
  end

end
