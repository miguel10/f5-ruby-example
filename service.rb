include_recipe "f5-node-initiator::install"

# Retrieve F5 Credential from Encrypted databag
begin
  f5pass = Chef::EncryptedDataBagItem.load('f5credential', node.chef_environment, node[:f5credential][:dbpw])
rescue
  f5pass = { "key" => "KEY" }
end

# Join pool if the server is not already part of the pool
execute "f5-node-initiator" do
  command "/opt/f5-node-initiator/f5_node_initiator.rb -H #{node[:f5][:host]} -u #{node[:f5][:user]} -p #{f5pass["key"]} -n #{node[:f5][:poolname]} -a #{node[:ipaddress]} -t #{node[:f5][:webport]} -r #{node[:f5][:partition]}"
  sensitive true
  not_if "/opt/f5-node-initiator/f5_node_verify.rb -H #{node[:f5][:host]} -u #{node[:f5][:user]} -p #{f5pass["key"]} -n #{node[:f5][:poolname]} -a #{node[:ipaddress]} -t #{node[:f5][:webport]} -r #{node[:f5][:partition]}"
end

