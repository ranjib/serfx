# encoding: UTF-8
#
require 'spec_helper'
require 'pry'

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
    expect(conn.members.body['Members'].last['Status']).to eq('leaving')
  end
end
