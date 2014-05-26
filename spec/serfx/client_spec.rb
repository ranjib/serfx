# encoding: UTF-8
#
require 'spec_helper'
require 'timeout'
require 'thread'

describe Serfx do

  before(:all) do
    start_cluster(5)
  end

  after(:all) do
    stop_cluster
  end

  before(:each) do
    @conn = Serfx::Connection.new(port: 5000, authkey: 'awesomesecret')
    @conn.handshake
    @conn.auth
  end

  after(:each) do
    @conn.close
  end

  let(:new_connection) do
    Serfx::Connection.new(port: 5000, authkey: 'awesomesecret')
  end

  it '#handshake' do
    conn = new_connection
    response = conn.handshake
    conn.close
    expect(response.header.error).to be_empty
    expect(response.header.seq).to eq(1)
  end

  it '#auth' do
    conn = new_connection
    conn.handshake
    response = conn.auth
    conn.close
    expect(response.header.error).to be_empty
  end

  it '#event' do
    response = @conn.event('seriously')
    expect(response.header.error).to be_empty
  end

  it '#force-leave' do
    last_pid = Serfx::SpecHelper::Spawner.instance.pids.pop
    Process.kill('TERM', last_pid)
    response = @conn.force_leave('node_4')
    expect(response.header.error).to be_empty
    time = 0
    expect do
      Timeout.timeout(10) do
        node = @conn.members.body['Members'].find do |n|
          n['Name'] == 'node_4'
        end
        until node['Status'] == 'left'
          time += 1
          sleep 1
          node = @conn.members.body['Members'].find do |n|
            n['Name'] == 'node_4'
          end
        end
      end
    end.to_not raise_error
  end

  it '#join' do
    Serfx::SpecHelper::Spawner.instance.start(1, join: false)
    sleep 3
    @conn.join(['127.0.0.1:4000'])
    sleep 2
    expect(@conn.members.body['Members'].size).to eq(5)
  end

  it '#members' do
    response = @conn.members
    expect(response.header.error).to be_empty
    expect(response.body['Members'].size).to eq(5)
  end

  it '#members-filtered' do
    response = @conn.members_filtered('group' => 'odd')
    expect(response.header.error).to be_empty
    tags = response.body['Members'].map { |x|x['Tags']['group'] }
    expect(tags.all? { |t| t == 'odd' }).to be_true
  end

  it '#tags' do
    response = @conn.tags('service' => 'foo')
    expect(response.header.error).to be_empty
    response = @conn.members_filtered('service' => 'foo')
    expect(response.body['Members']).to_not be_empty
  end

  it '#stream and stop' do
    Serfx.connect(port: 5000, authkey: 'awesomesecret') do |c|
      data = nil
      _, t = c.stream('user:test') do |event|
        data = event
      end
      sleep 2
      @conn.event('test', 'whoa')
      sleep 2
      t.kill
      expect(data['Name']).to eq('test')
      expect(data['Payload']).to eq('whoa')
      expect(data['Coalesce']).to be_true
      expect(data['Event']).to eq('user')
    end
  end

  it '#stream, query, respond and stop' do
    Serfx.connect(port: 5000, authkey: 'awesomesecret') do |c|
      res, t = c.stream('query') do |q|
        c.respond(q['ID'], q['Payload'].to_s.upcase) if q['ID']
      end
      sleep 3
      @conn.query('test', 'whoa') do |r|
        expect(r['Payload']).to eq('WHOA')
      end
      c.stop(res.header.seq)
      t.kill
    end
  end
end
