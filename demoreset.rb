#!/usr/bin/env ruby

#Reset images

require 'open3'
require 'colorize'
require 'fileutils'

servers = ['centos7a.pdx.puppet.vm','centos7b.pdx.puppet.vm']

def imagereset(imagename)
  stdout, stderr, status = Open3.capture3('openstack', 'server', 'rebuild', imagename)
  if status.success?
    puts '### '.yellow + "Rebuilding #{imagename}"
    if stdout.include? 'rebuilding'
      output = stdout
      output_rebuild = output.split(/\n+/)
      output_rebuild.each do |readline|
        if readline.include? 'updated'
        rl_split =readline.split('|')
        rl_date_slice=rl_split[2]
        rl_date_localout = rl_date_slice.split('T')
        rl_date_lo_split = rl_date_localout[1]
        puts '### '.yellow + "Updated #{rl_date_lo_split}"
        puts ''
        end
      end
    end
  end
end

# Delete node certificate on Puppet Master
def delete_cert(imagename)
  stdout, stderr, status = Open3.capture3('/usr/local/bin/bolt', 'command', 'run', "/usr/local/bin/puppet cert clean #{imagename}", '-n', 'slice-master', '-u', 'root', '--tty') 
  if stdout.include? 'Revoked'
    delete_hash = '###'.yellow
    delete_msg = "Node #{imagename} certificate has been revoked."
    puts "#{delete_hash} " + "#{delete_msg}"
  end
end

# Purge node on Puppet Master
def purge_node(imagename)
  stdout, stderr, status = Open3.capture3('/usr/local/bin/bolt', 'command', 'run', "/usr/local/bin/puppet node purge #{imagename}", '-n', 'slice-master', '-u', 'root', '--tty') 
  if stdout.include? 'was purged.'
    purge_hash = '###'.yellow
    purge_msg = "Node #{imagename} certificate has been purged."
    puts "#{purge_hash} " + "#{purge_msg}"
  end
end

# Remove SSH entries in authorized_keys file.
def remove_lines(f)
  open(f, 'r') do |f1|
    open("#{f}.tmp", 'w') do |f2|
      f.each_line do |line|
        f2.write(line) unless line.start_with? "centos-7"
      end
    end
  end
end

# Remove SSL certificates and run Puppet agent to recreate new keys.
def reset_pe_agent(imagename)
  if imagename.include? 'server2012r2'
    stdout, stderr, status = Open3.capture3('/usr/local/bin/bolt', 'command', 'run', "C:\Program Files\Puppet Labs\Puppet\bin\puppet agent -t", '-n', imagename, '--transport', 'winrm', '-u', 'Administrator', '-p', 'Puppet4Life!')
  else imagename.include? 'centos'
    stdout, stderr, status = Open3.capture3('/usr/local/bin/bolt', 'command', 'run', "rm -rf /etc/puppetlabs/puppet/ssl", '--run-as', 'root', '-n', imagename, '-u', 'centos', '--tty')
    reset_centos_hash = '###'.yellow
    reset_centos_msg = "Deleting #{imagename} local SSL certificates, before running Puppet to recreate keys."
    puts "#{reset_centos_hash} " + "#{reset_centos_msg}"
    stdout, stderr, status = Open3.capture3('/usr/local/bin/bolt', 'command', 'run', "/usr/local/bin/puppet agent -t", '--run-as', 'root', '-n', imagename, '-u', 'centos', '--tty')
    if stdout.include? 'Applied catalog'
      puts "### Puppet Agent #{imagename} now connected to Puppet Master ###".green
      puts ''
    else
      puts 'Something went wrong while refreshing certificates on this node.'.colorize(:red)
      puts stdout
    end
  end
end

servers.each do |readsrv|
  #imagereset(readsrv)
  #delete_cert(readsrv)
  #purge_node(readsrv)
  #reset_pe_agent(readsrv)
  remove_lines('/Users/tommy/.ssh/known_hosts')
end
