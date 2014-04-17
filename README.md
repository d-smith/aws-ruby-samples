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
RDS instance in the VPC. This is useful for creating an initial RDS instance.
The launch_bastion_and_private.rb script launches a bastion host and
instance in a private subnet. After fixing the hosts file (see below) SQL*Net
can be used from the private host for building the schema. Once the schema
has been created, a snapshot can be created, after which new instances with the
snapshot-ed schema can be created using the launch_rds_from_snapshot.rb. Note
that when launching from a snapshot, there's no way to override the default
security group with the VPC security. Once the instance is active,
the update_db_security_group.rc script can be run to restrict access to the RDS
instance to the private subnets in the VPC.

Permissions
----------------

Running the scripts required some additional policies granting API access
for load balancer and auto scaling configuration. Here are the
additional policies I had to create:

    {
      "Version": "2012-10-17",
      "Statement":[{
      "Effect":"Allow",
      "Action":[
          "autoscaling:*LaunchConfiguration*",
          "autoscaling:*DescribeAutoScalingGroups*",
          "autoscaling:DescribePolicies",
          "autoscaling:CreateAutoScalingGroup",
          "autoscaling:PutScalingPolicy"
      ],
      "Resource":"*"
      }
      ]
    }

    {
      "Version": "2012-10-17",
       "Statement":[{
          "Effect":"Allow",
          "Action":["cloudwatch:DescribeAlarms",
                    "cloudwatch:PutMetricAlarm"
          ],
          "Resource":"*"
          }  
       ]
    }

    {
      "Version": "2012-10-17",
      "Statement":[{
        "Effect":"Allow",
        "Action":["elasticloadbalancing:CreateLoadBalancer",
                "elasticloadbalancing:ConfigureHealthCheck",
                "elasticloadbalancing:DeleteLoadBalancer"],
                "Resource":"*"
              }  
      ]
    }  




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
