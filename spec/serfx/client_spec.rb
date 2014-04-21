# encoding: UTF-8
#
require 'spec_helper'
require 'pry'
require 'timeout'

describe Serfx::Client do

  before(:all) do
    start_cluster(5)
  end

  after(:all) do
    stop_cluster
  end

  let(:conn) do
    Serfx::Connection.new('127.0.0.1', 5000, 'awesomesecret')
  end

  it '#handshake' do
    response = conn.handshake
    expect(response.header.error).to be_empty
    expect(response.header.seq).to eq(1)
  end

  it '#auth' do
    response = conn.auth
    expect(response.header.error).to be_empty
  end

  it '#members' do
    response = conn.members
    expect(response.header.error).to be_empty
    expect(response.body['Members'].size).to eq(5)
  end

  it '#event' do
    response = conn.event('seriously')
    expect(response.header.error).to be_empty
  end

  it '#force-leave' do
    last_pid = Serfx::SpecHelper::Spawner.instance.pids.pop
    Process.kill('TERM', last_pid)
    response = conn.force_leave('node_4')
    expect(response.header.error).to be_empty
    n = 0
    expect do
      Timeout.timeout(10) do
        node = conn.members.body['Members'].detect{|n|n['Name'] == 'node_4'}
        until node['Status'] == 'left'
          n= n+1
          sleep 1
          node = conn.members.body['Members'].detect{|n|n['Name'] == 'node_4'}
        end
        #puts "Status: #{node['Status']}. Time taken: #{n} seconds)"
      end
    end.to_not raise_error
  end

  it '#join' do
    Serfx::SpecHelper::Spawner.instance.start(1, join: false)
    sleep 3
    c2 = Serfx::Connection.new('127.0.0.1', 5004, 'awesomesecret')
    c2.join(['127.0.0.1:4000'])
    sleep 2
    expect(c2.members.body['Members'].size).to eq(5)
  end
end
