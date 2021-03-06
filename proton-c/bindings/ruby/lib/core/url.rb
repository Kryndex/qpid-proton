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


module Qpid::Proton

  # @deprecated use {URI} or {String}
  class URL

    attr_reader :scheme
    attr_reader :username
    alias user username
    attr_reader :password
    attr_reader :host
    attr_reader :port
    attr_reader :path

    # Parse a string, return a new URL
    # @param url [#to_s] the URL string
    def initialize(url = nil)
      Qpid.deprecated self.class, 'URI or String'
      if url
        @url = Cproton.pn_url_parse(url.to_s)
        if @url.nil?
          raise ::ArgumentError.new("invalid url: #{url}")
        end
      else
        @url = Cproton.pn_url
      end
      @scheme = Cproton.pn_url_get_scheme(@url)
      @username = Cproton.pn_url_get_username(@url)
      @password = Cproton.pn_url_get_password(@url)
      @host = Cproton.pn_url_get_host(@url)
      @port = Cproton.pn_url_get_port(@url)
      @path = Cproton.pn_url_get_path(@url)
      defaults
    end

    def port=(port)
      if port.nil?
        Cproton.pn_url_set_port(@url, nil)
      else
        Cproton.pn_url_set_port(@url, port)
      end
    end

    def port
      Cproton.pn_url_get_port(@url).to_i
    end

    # @return [String] Convert to string
    def to_s
      "#{@scheme}://#{@username.nil? ? '' : @username}#{@password.nil? ? '' : '@' + @password + ':'}#{@host}:#{@port}/#{@path}"
    end

    # @return [String] Allow implicit conversion by {String#try_convert}
    alias to_str to_s

    private

    def defaults
      @scheme = @scheme || "amqp"
      @host = @host || "0.0.0.0"
      @port = @port || 5672
    end
  end
end
