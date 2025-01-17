#!/usr/bin/env rspec
# frozen_string_literal: true

require 'spec_helper'
require 'puppet/confine/exists'

describe 'iptables chain' do
  describe 'iptables chain provider detection' do
    let(:exists) do
      Puppet::Confine::Exists
    end

    before :each do
      # Reset the default provider
      Puppet::Type.type(:firewallchain).defaultprovider = nil

      # Stub confine facts
      allow(Facter.fact(:kernel)).to receive(:value).and_return('Linux')
      allow(Facter.fact(:operatingsystem)).to receive(:value).and_return('Debian')

      # Stub lookup for /sbin/iptables & /sbin/iptables-save
      allow(exists).to receive(:which).with('ebtables')
                                      .and_return '/sbin/ebtables'
      allow(exists).to receive(:which).with('ebtables-save')
                                      .and_return '/sbin/ebtables-save'

      allow(exists).to receive(:which).with('iptables')
                                      .and_return '/sbin/iptables'
      allow(exists).to receive(:which).with('iptables-save')
                                      .and_return '/sbin/iptables-save'

      allow(exists).to receive(:which).with('ip6tables')
                                      .and_return '/sbin/ip6tables'
      allow(exists).to receive(:which).with('ip6tables-save')
                                      .and_return '/sbin/ip6tables-save'

      # Every other command should return false so we don't pick up any
      # other providers
      allow(exists).to receive(:which) { |value|
        value !~ %r{(eb|ip|ip6)tables(-save)?$}
      }.and_return false
    end

    it 'defaults to iptables provider if /sbin/(eb|ip|ip6)tables[-save] exists' do
      # Create a resource instance and make sure the provider is iptables
      resource = Puppet::Type.type(:firewallchain).new(name: 'test:filter:IPv4')
      expect(resource.provider.class.to_s).to eq('Puppet::Type::Firewallchain::ProviderIptables_chain')
    end
  end

  describe 'iptables chain provider' do
    let(:provider) { Puppet::Type.type(:firewallchain).provider(:iptables_chain) }
    let(:resource) do
      Puppet::Type.type(:firewallchain).new(name: ':test:')
    end

    before :each do
      allow(Puppet::Type::Firewallchain).to receive(:defaultprovider).and_return provider
      allow(provider).to receive(:command).with(:ebtables_save).and_return '/sbin/ebtables-save'
      allow(provider).to receive(:command).with(:iptables_save).and_return '/sbin/iptables-save'
      allow(provider).to receive(:command).with(:ip6tables_save).and_return '/sbin/ip6tables-save'

      # Pretend to return nil from iptables
      allow(provider).to receive(:execute).with(['/sbin/ip6tables-save']).and_return('')
      allow(provider).to receive(:execute).with(['/sbin/ebtables-save']).and_return('')
      allow(provider).to receive(:execute).with(['/sbin/iptables-save']).and_return('')
    end

    it 'is able to get a list of existing rules' do
      provider.instances.each do |chain|
        expect(chain).to be_instance_of(provider)
        expect(chain.properties[:provider].to_s).to eq(provider.name.to_s)
      end
    end
  end

  describe 'iptables chain resource parsing' do
    let(:provider) { Puppet::Type.type(:firewallchain).provider(:iptables_chain) }

    before :each do
      ebtables = ['BROUTE:BROUTING:ethernet',
                  'BROUTE:broute:ethernet',
                  ':INPUT:ethernet',
                  ':FORWARD:ethernet',
                  ':OUTPUT:ethernet',
                  ':filter:ethernet',
                  ':filterdrop:ethernet',
                  ':filterreturn:ethernet',
                  'NAT:PREROUTING:ethernet',
                  'NAT:OUTPUT:ethernet',
                  'NAT:POSTROUTING:ethernet']
      allow(provider).to receive(:execute).with(['/sbin/ebtables-save']).and_return('
  *broute
  :BROUTING ACCEPT
  :broute ACCEPT

  *filter
  :INPUT ACCEPT
  :FORWARD ACCEPT
  :OUTPUT ACCEPT
  :filter ACCEPT
  :filterdrop DROP
  :filterreturn RETURN

  *nat
  :PREROUTING ACCEPT
  :OUTPUT ACCEPT
  :POSTROUTING ACCEPT
  ')

      iptables = [
        'raw:PREROUTING:IPv4',
        'raw:OUTPUT:IPv4',
        'raw:raw:IPv4',
        'mangle:PREROUTING:IPv4',
        'mangle:INPUT:IPv4',
        'mangle:FORWARD:IPv4',
        'mangle:OUTPUT:IPv4',
        'mangle:POSTROUTING:IPv4',
        'mangle:mangle:IPv4',
        'NAT:PREROUTING:IPv4',
        'NAT:OUTPUT:IPv4',
        'NAT:POSTROUTING:IPv4',
        'NAT:mangle:IPv4',
        'NAT:mangle:IPv4',
        'NAT:mangle:IPv4',
        'security:INPUT:IPv4',
        'security:FORWARD:IPv4',
        'security:OUTPUT:IPv4',
        ':$5()*&%\'"^$): :IPv4',
      ]
      allow(provider).to receive(:execute).with(['/sbin/iptables-save']).and_return('
  # Generated by iptables-save v1.4.9 on Mon Jan  2 01:20:06 2012
  *raw
  :PREROUTING ACCEPT [12:1780]
  :OUTPUT ACCEPT [19:1159]
  :raw - [0:0]
  COMMIT
  # Completed on Mon Jan  2 01:20:06 2012
  # Generated by iptables-save v1.4.9 on Mon Jan  2 01:20:06 2012
  *mangle
  :PREROUTING ACCEPT [12:1780]
  :INPUT ACCEPT [12:1780]
  :FORWARD ACCEPT [0:0]
  :OUTPUT ACCEPT [19:1159]
  :POSTROUTING ACCEPT [19:1159]
  :mangle - [0:0]
  COMMIT
  # Completed on Mon Jan  2 01:20:06 2012
  # Generated by iptables-save v1.4.9 on Mon Jan  2 01:20:06 2012
  *nat
  :PREROUTING ACCEPT [2242:639750]
  :OUTPUT ACCEPT [5176:326206]
  :POSTROUTING ACCEPT [5162:325382]
  COMMIT
  # Completed on Mon Jan  2 01:20:06 2012
  # Generated by iptables-save v1.4.9 on Mon Jan  2 01:20:06 2012
  *filter
  :INPUT ACCEPT [0:0]
  :FORWARD DROP [0:0]
  :OUTPUT ACCEPT [5673:420879]
  :$5()*&%\'"^$):  - [0:0]
  COMMIT
  # Completed on Mon Jan  2 01:20:06 2012
  ')
      ip6tables = [
        'raw:PREROUTING:IPv6',
        'raw:OUTPUT:IPv6',
        'raw:ff:IPv6',
        'mangle:PREROUTING:IPv6',
        'mangle:INPUT:IPv6',
        'mangle:FORWARD:IPv6',
        'mangle:OUTPUT:IPv6',
        'mangle:POSTROUTING:IPv6',
        'mangle:ff:IPv6',
        'security:INPUT:IPv6',
        'security:FORWARD:IPv6',
        'security:OUTPUT:IPv6',
        ':INPUT:IPv6',
        ':FORWARD:IPv6',
        ':OUTPUT:IPv6',
        ':test:IPv6',
      ]
      allow(provider).to receive(:execute).with(['/sbin/ip6tables-save']).and_return('
  # Generated by ip6tables-save v1.4.9 on Mon Jan  2 01:31:39 2012
  *raw
  :PREROUTING ACCEPT [2173:489241]
  :OUTPUT ACCEPT [0:0]
  :ff - [0:0]
  COMMIT
  # Completed on Mon Jan  2 01:31:39 2012
  # Generated by ip6tables-save v1.4.9 on Mon Jan  2 01:31:39 2012
  *mangle
  :PREROUTING ACCEPT [2301:518373]
  :INPUT ACCEPT [0:0]
  :FORWARD ACCEPT [0:0]
  :OUTPUT ACCEPT [0:0]
  :POSTROUTING ACCEPT [0:0]
  :ff - [0:0]
  COMMIT
  # Completed on Mon Jan  2 01:31:39 2012
  # Generated by ip6tables-save v1.4.9 on Mon Jan  2 01:31:39 2012
  *filter
  :INPUT ACCEPT [0:0]
  :FORWARD DROP [0:0]
  :OUTPUT ACCEPT [20:1292]
  :test - [0:0]
  COMMIT
  # Completed on Mon Jan  2 01:31:39 2012
  ')
      @all = ebtables + iptables + ip6tables
      # IPv4 and IPv6 names also exist as resources {table}:{chain}:IP and {table}:{chain}:
      iptables.each { |name| @all += [name[0..-3], name[0..-5]] }
      ip6tables.each { |name| @all += [name[0..-3], name[0..-5]] }
    end

    it 'has all in parsed resources' do
      provider.instances.each do |resource|
        @all.include?(resource.name) # rubocop:disable RSpec/InstanceVariable
      end
    end
  end
end
