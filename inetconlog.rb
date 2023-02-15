#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

# Copyright (c) 2023  Thilo Fischer.
# Free software licensed under GPL v3. See LICENSE.txt for details.

require 'date'

DEFAULT_IP4_HOSTS = [ '8.8.8.8', '8.8.4.4' ]
DEFAULT_IP6_HOSTS = [ '2001:4860:4860::8888', '2001:4860:4860::8844' ]
DEFAULT_DNS_HOSTS = [ 'www.google.com', 'www.wikipedia.org', 'www.amazon.com', 'www.whatismyip.com' ] # 'www.whatsmyip.org', 'www.ietf.org', ...
DEFAULT_HTTP_HOSTS = DEFAULT_DNS_HOSTS
DEFAULT_WWW_HOSTS = DEFAULT_DNS_HOSTS.map { |h| 'https://' + h }

def log(heading, details = '')
  puts(DateTime.now.strftime('%y-%m-%d %T') + ' > ' + heading)
  details.each_line { |l| puts('        ' + l) }
  puts
end

class CheckGroup
  def initialize(hosts)
    @hosts = hosts
    @state = []
    @iter = @hosts.length
  end

  def check()
    @iter += 1
    @iter = 0 if @iter >= @hosts.length
    host = @hosts[@iter]
    output = command(host)
    success = $?.success?
    if @state[@iter] != success
      log(label + "(#{host}) " + (success ? 'OK' : 'FAILED' ) + ' ', output)
      @state[@iter] = success
    end
    result_string(@iter)
  end

  def all_ok?
    @state.all? { |i| i }
  end

  def all_fail?
    @state.all? { |i| i == false }
  end

  def result_string(iter = -1)
    result = label + ':'
    @state.each_with_index do |state, index|
      if index == iter
        result += state ? '*' : '-'
      else
        result += state ? '+' : '_'
      end
    end
    result
  end

  def to_s
    result_string
  end
end

class PingGroup < CheckGroup
  def label
    'ping'
  end
  def command(host)
    `ping -c 1 #{host} 2>&1`
  end
end

class CurlGroup < CheckGroup
  def label
    'curl http HEAD'
  end
  def command(host)
    `curl --head --output /dev/null #{host} 2>&1`
  end
end

class WgetGroup < CheckGroup
  def label
    'wget'
  end
  def command(host)
    `wget --tries=1 --output-document=/dev/null #{host} 2>&1`
  end
end


class Speedtest
  def initialize
    @state = false
  end

  def run
    output = `speedtest-cli 2>&1`
    success = $?.success?
    if @state != success
      log('Speedtest', output)
      @state = success
    elsif success
      lines = output.lines.grep(/^(Upload|Download)/)
      log("Speedtest => #{lines[0].chomp} / #{lines[1].chomp}")
    end
  end
end

log("Start Internet Connection Logging at " + DateTime.now.iso8601)

ping4 = PingGroup.new(DEFAULT_IP4_HOSTS)
ping6 = PingGroup.new(DEFAULT_IP6_HOSTS)
ping_dns = PingGroup.new(DEFAULT_DNS_HOSTS)

http = CurlGroup.new(DEFAULT_HTTP_HOSTS)

www = WgetGroup.new(DEFAULT_WWW_HOSTS)

speedtest = Speedtest.new

iter = 0
states = {}

while true

  case iter % 3
  when 0
    states[:p4] = ping4.check()
    states[:pDns] = ping_dns.to_s
  when 1
    states[:p6] = ping6.check()
    states[:p4] = ping4.to_s
  when 2
    states[:pDns] = ping_dns.check()
    states[:p6] = ping6.to_s
  end

  case iter % 10
  when 0
    states[:http] = http.check()
  when 1
    states[:http] = http.to_s
  when 5
    states[:www] = www.check()
  when 6
    states[:www] = www.to_s
  end

  case iter % 30
  when 0
    speedtest.run
    iter = 0
  end

  
  STDERR.puts("#{DateTime.now} #{states[:p4]} #{states[:p6]} #{states[:pDns]} #{states[:http]} #{states[:www]}")

  iter += 1
  sleep(120)
  
end
