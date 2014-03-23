# delta\_reporting #

Delta Reporting provides centralized CFEngine class and promise reporting via a modern and responsive web application.

## Features ##
- Report on class membership history.
- Report on low level promise compliance history.
- Inventory reporting.
- Centralize all your CFEngine servers to a single reporting database.
- IPV6 ready.
- Use you existing database infrastructure.
- Sort and filter your report results.
- Save your reports in multiple formats.

## Requirements ##

### Client and Server ###
# CFEngine 3.5.2+
# [EFL]:https://github.com/evolvethinking/evolve\_cfengine\_freelib/, the Evolve Thinking free promise library. It very important that you know how to use this.
# Perl 5.10+

### Server ###
# Perl Module NET::DNS
# Perl Module DBI
# Perl Module DBD::Pg
# Postgresql 8.3+
# Apache recommended for proxy front end.

## Support ##

Evolve Thinking is the creator and caretaker of Delta Reporting. They offer professional support services for Delta Reporting, CFEngine, and other IT services. ( http://evolvethinking.com ).

## How it works ##

Using the provided the CFEngine policy in delta\_reporting.cf all CFEngine class and all promises using EFL are logged by cf-agent on the host and stored for pickup by the policy server. The policy server downloads the log from every client and inserts them into the database.

## Installation ##

# Install prerequisites.

# Create database delta\_reporting.

# Install contents of repo to /opt/delta\_reporting/.

# Configure using DeltaR.conf. Be sure to configure your database properly for authentication and authorization.

# Copy bin/delta\_reporting script to /etc/init.d. This is your start script. Run it.

# Go to http://localhost:8080/initialize\_database.

# You can DR run as is, or proxy behind Apache:

`<VirtualHost *:80>
   ServerName ettin.example.com
   ProxyPass / http://localhost:8080/
   ProxyPassReverse / http://localhost:8080/

   <LocationMatch /.*>
      AuthUserFile /etc/apache2/passwords.secret
      AuthType Basic
      AuthName 'Evolve Thinking Delta Reporting'
      Require valid-user
   </LocationMatch>
</VirtualHost>`

# Install delta\_reporting.cf into your CFEngine policy. Run bundles in the following order. Use of EFL's main methods bundle is encouraged. Don't forget the null parameters.
## deltarep\_prelogging as early as possible on all hosts.
## deltarep\_postlogging as late as possible on all hosts.
## deltarep\_client\_get after deltarep\_postlogging on policy servers only.

# Define the namespace class delta\_reporting for all hosts, as early as possible.

# Install bin/dhlogmaker and configure CFEngine to install it on all hosts. /opt/delta\_reporting/bin/dhlogmaker suggested. 

# Create server access promises that allow the policy server's agent to download from cf-serverd on all agents, including itself, the directory ${sys.workdir}/delta\_reporting. Use of the EFL bundle efl\_server is encouraged.

## License ##

Copyright Evolve Thinking ( [www.evolvethinking.com]:www.evolvethinking.com  ).

Delta Reporting is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program. If not, see [http://www.gnu.org/licenses/]:http://www.gnu.org/licenses/.
