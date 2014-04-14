Overview
-----------------

The create_vpn.rb script creates a VPC with three subnets, one in which
servers can be accessed via ssh from anywhere, and two private subnets. We
need two private subnets for launching an RDS instance in the VPC.

After running this script, launch public instances in the VPC specifying the 
public subnet in us-east-1d, with a public IP address, and use the 
launch-sg created by the script.

Private instances are launched in the us-east-1c or us-east-1a subnets, with a private
IP address (e.g. 10.0.1.99) using the private-subnet-launch-sg security
group.

The launch_rds.rb script creates an RDS security group and launches an
RDS instance in the VPC.

Oracle Connection Details
-----------------------------

To connect to the RDS instance, launch an EC2 server in the VPC. You will need to install the Oracle instant
client - grab it from the OTN [here](http://www.oracle.com/technetwork/topics/linuxx86-64soft-092277.html)

You will need the basic and sqlplus RPMs.

The RPMs are installed via 

    rpm -i oracle-instantclient12.1-basic-12.1.0.1.0-1.x86_64.rpm
    rpm -i oracle-instantclient12.1-sqlplus-12.1.0.1.0-1.x86_64.rpm
  
The lib and bin directories located here:

    /usr/lib/oracle/12.1/client64/lib
    /usr/lib/oracle/12.1/client64/bin
  
To use sqlplus, update your PATH and LD_LIBRARY_PATH settings in your .bash_profile

    PATH=$PATH:$HOME/bin:/usr/lib/oracle/12.1/client64/bin
    LD_LIBRARY_PATH=/usr/lib/oracle/12.1/client64/lib:$LD_LIBRARY_PATH
    export PATH
    export LD_LIBRARY_PATH

Now you can connect to your oracle RDS instance:

    sqlplus 'user@(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=aws-host)(PORT=1521))(CONNECT_DATA=(SID=RDS-SID)))'
  
When I tried this initially, I received the following error:

    ERROR:
    ORA-21561: OID generation failed
  
The solution was to edit /etc/hosts to include the hostname in the localhost line:

    127.0.0.1   localhost ip-10-0-0-93
  
  



