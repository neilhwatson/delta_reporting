# Architecture #

Delta Reporting is an MVC application powered by the Mojolicous framework.

## Layout ##

Here is the tree layout for the the app directory.

    ├── DeltaR.conf
    ├── DeltaR.pl

DeltaR.conf is the application config file.  DeltaR.pl is the Mojolicious appliation start file.

    ├── lib

Lib contains the Delta Reporting application custom Perl modules. 

    │   ├── DeltaR
    │   │   ├── Command
    │   │   │   ├── load.pm
    │   │   │   ├── prune.pm
    │   │   │   ├── query.pm
    │   │   │   └── trends.pm

Command modules are use by command line utilities.

    │   │   ├── Form.pm

Form produces web forms.

    │   │   ├── Graph.pm

Graph produces trend and other graphs.

    │   │   ├── Query.pm

Query contains database related subroutines.

    │   │   └── Report.pm

Report produces report table pages.

    │   └── DeltaR.pm

DeltaR.pm is the main Mojolicious controller and router.

    ├── public

Public contains static files like css, js, and images.

    ├── script

Script contains the command line utilities. Technically they are shell wrappers for Perl scripts.

    │   ├── delta-cron

Used for database chores.

    │   ├── load

Used to load agent logs in to the database.

    │   ├── morbo

Use this to start a webserver for developing.

    │   ├── prune

Called by delta-cron.

    │   ├── query

Called by delta-cron.

    │   ├── reduce

Called by delta-cron.

    │   └── trends

Called by delta-cron.

    └── templates

Contains templates to produce web pages.

        ├── form

Contains web form templates.

        ├── layouts

Contains the top level layouts for all templates.

        ├── report

Contains report templates.

## License ##

Delta Reporting is a central server compliance log that uses CFEngine.

Copyright (C) 2016 Neil H. Watson http://watson-wilson.ca

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
