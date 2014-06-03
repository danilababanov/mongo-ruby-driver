require 'spec_helper'

describe Mongo::Cluster do

  let(:client) do
    double('client')
  end

  describe '#==' do

    let(:addresses) do
      ['127.0.0.1:27017']
    end

    let(:cluster) do
      described_class.new(client, addresses)
    end

    context 'when the other is not a cluster' do

      it 'returns false' do
        expect(cluster).to_not eq('test')
      end
    end

    context 'when the other is a cluster' do

      context 'when the servers are equal' do

        let(:other) do
          described_class.new(client, addresses)
        end

        it 'returns true' do
          expect(cluster).to eq(other)
        end
      end

      context 'when the servers are not equal', simulator: 'cluster' do

        let(:other) do
          described_class.new(client, ['127.0.0.1:27020'])
        end

        it 'returns false' do
          expect(cluster).to_not eq(other)
        end
      end
    end
  end

  describe '#add', simulator: 'cluster' do

    let(:addresses) do
      ['127.0.0.1:27018', '127.0.0.1:27019']
    end

    let(:cluster) do
      described_class.new(client, addresses)
    end

    context 'when a server with the address does not exist' do

      let(:address) do
        '127.0.0.1:27021'
      end

      let!(:added) do
        cluster.add(address)
      end

      before do
        simulator.add('127.0.0.1:27021')
        cluster.check!
      end

      after do
        simulator.remove('127.0.0.1:27021')
      end

      it 'adds the server to the cluster' do
        expect(cluster.servers.size).to eq(4)
      end
    end

    context 'when a server with the address exists' do

      let!(:added) do
        cluster.add('127.0.0.1:27018')
      end

      before do
        cluster.check!
      end

      it 'does not add the server to the cluster' do
        expect(cluster.servers.size).to eq(2)
      end

      it 'returns nil' do
        expect(added).to be_nil
      end
    end
  end

  describe '#initialize', simulator: 'cluster' do

    let(:addresses) do
      ['127.0.0.1:27017', '127.0.0.1:27019']
    end

    let(:servers) do
      addresses.map { |address| Mongo::server.new(address) }
    end

    let(:cluster) do
      described_class.new(client, addresses)
    end

    it 'sets the configured addresses' do
      expect(cluster.addresses).to eq(addresses)
    end

    it 'sets the client' do
      expect(cluster.client).to eq(client)
    end

    context 'when the cluster is a replica set' do

      context 'when servers are discovered' do

        let(:cluster) do
          described_class.new(client, addresses)
        end

        before do
          cluster.check!
        end

        it 'automatically adds the members to the cluster' do
          expect(cluster.servers.size).to eq(4)
        end
      end
    end
  end

  describe '#servers', simulator: 'cluster' do

    let(:addresses) do
      ['127.0.0.1:27017', '127.0.0.1:27019']
    end

    let(:cluster) do
      described_class.new(client, addresses)
    end

    let(:servers_internal) do
      cluster.instance_variable_get(:@servers)
    end

    context 'when all servers are alive' do

      before do
        cluster.check!
      end

      it 'returns all servers' do
        expect(cluster.servers.size).to eq(4)
      end
    end

    context 'when some servers are not alive' do

      before do
        expect(servers_internal.first).to receive(:operable?).and_return(true)
        expect(servers_internal.last).to receive(:operable?).and_return(false)
      end

      it 'returns all alive servers' do
        expect(cluster.servers.size).to eq(1)
      end
    end
  end
end
