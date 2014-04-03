The create_vpn.rb script creates a VPC with two subnets, one in which
servers can be accessed via ssh from anywhere, and a private subnet.

After running this script, launch public instances in the VPC specifying the 
public subnet in us-east-1d, with a public IP address, and use the 
launch-sg created by the script.

Private instances are launched in the us-east-1c subnet, with a private
IP address (e.g. 10.0.1.99) using the private-subnet-launch-sg security
group.


