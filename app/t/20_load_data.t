use lib './lib';
use Test::More;
use Test::Exception;
use Test::Mojo;
use POSIX( 'strftime' );
use Storable;
use strict;
use warnings;

my $hosts = 2;
my @log_data;

my $missing_timestamp =
   strftime "%Y-%m-%dT%H:%M:%S%z", localtime( time - 60**2 * 36 );
my $trend_timestamp =
   strftime "%Y-%m-%dT%H:%M:%S%z", localtime( time - 60**2 * 24 );

## Create historical trend data
my @historical_trends;
for my $day ( -7..-2 )
{
   my $datestamp = strftime "%Y-%m-%d", localtime( time - 60**2 * 24 * -$day );
   my $kept      = int( rand( 200 ) + 900 );
   my $notkept   = int( rand( 200 ) + 900 );
   my $repaired  = int( rand( 200 ) + 900 );

   push @historical_trends,
      [ 
         $datestamp,
         $hosts,
         $kept,
         $notkept,
         $repaired
      ];
}

# Load historical trend data
my $t = Test::Mojo->new( 'DeltaR' );
lives_and {
   ok( $t->app->dw->insert_promise_counts( \@historical_trends ) )
} 'Load test historical trend data';

# Load stored shared data
my $shared = retrieve( '/tmp/delta_reporting_test_data' );
ok( defined $shared, 'Load shared data' );

# Prep test client log data for loading
for my $line (<DATA>) {
   chomp $line;
   push @log_data, $line;
}

# Load test client log data
for my $next_host ( 1..$hosts ) {
   my $hex = sprintf( "%x", $next_host );
   my $log_file = "/tmp/$shared->{data}{subnet}$hex.log";
   my @timestamps;
   
   if ( "$shared->{data}{subnet}$hex"
      eq $shared->{data}{missing_ip_address} )
   {
      @timestamps = ( $missing_timestamp );
   }
   else {
      @timestamps = ( $trend_timestamp, $shared->{data}{log_timestamp} );
   }

   for my $next_timestamp ( @timestamps ) {
      lives_and {
         ok( build_client_log({
               log_file  => $log_file,
               timestamp => $next_timestamp,
               log_data  => \@log_data
            })),
      } 'build log data for hosts';

      lives_and {
         ok( run_command( "./script/load $log_file" ));
      } 'Insert client log';

      unlink $log_file or warn "Cannot unlink [$log_file]";
   }
}

lives_and {
   ok( run_command( './script/prune'  ));
} 'Run command prune';

lives_and {
   ok( run_command( './script/reduce' ));
} 'Run command reduce';

lives_and {
   ok( run_command( './script/trends' ));
} 'Run command trends';

done_testing();

sub build_client_log {
   my ( $arg ) = @_;
   open( my $log_file, ">", $arg->{log_file} )
      or die "Cannot open log file [$arg->{log_file}], [$!]";

   for my $next_data ( @{ $arg->{log_data} } )
   {
      my $line = $arg->{timestamp} . ' ;; '. $next_data."\n";
      print $log_file $line or die "Cannot write [$line] to [$arg->{log_file}], [$!]";
   }
   close $log_file;
   return 1;
}

sub run_command
{
   my $command = shift;
   my $return = system( $command );
   if ( $return != 0 )
   {
      die "Error [$command] return status [$return]";
   }
   return 1;
}

=pod

=head1 SYNOPSIS

This is loads test data for later query tests.

=head1 LICENSE

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
=cut

## Test Data
# timestamp ;; class ;; promise_handle ;; promiser ;; promise_outcome ;; promisee
# Insert timestamp dynamically

__DATA__
any ;; empty ;; empty ;; empty ;; empty
dr_test_class ;; empty ;; empty ;; empty ;; empty
cfengine_3_dr_test ;; empty ;; empty ;; empty ;; empty
dr_test_kept ;; handle_dr_test ;; /etc/dr_test_kept ;; kept ;; mojolicious
dr_test_notkept ;; handle_dr_test ;; /etc/dr_test_notkept ;; notkept ;; mojolicious
127_0_0_1 ;; empty ;; empty ;; empty ;; empty
172_16_100_1 ;; empty ;; empty ;; empty ;; empty
2001_470_1d_a2f__2 ;; empty ;; empty ;; empty ;; empty
64_bit ;; empty ;; empty ;; empty ;; empty
8_cpus ;; empty ;; empty ;; empty ;; empty
agent ;; empty ;; empty ;; empty ;; empty
am_policy_hub ;; empty ;; empty ;; empty ;; empty
_bin_echo__lsb_release___lsb_release__cs__handle_efl_command_commands_repaired ;; efl_command_commands ;; /bin/echo =lsb_release=$(lsb_release -cs) ;; repaired ;; environment
ca ;; empty ;; empty ;; empty ;; empty
canada ;; empty ;; empty ;; empty ;; empty
cfengine_3_5_2 ;; empty ;; empty ;; empty ;; empty
cfengine_3_5 ;; empty ;; empty ;; empty ;; empty
cfengine_3 ;; empty ;; empty ;; empty ;; empty
cfengine ;; empty ;; empty ;; empty ;; empty
cfengine_in_high ;; empty ;; empty ;; empty ;; empty
cfengine_in_normal ;; empty ;; empty ;; empty ;; empty
community_edition ;; empty ;; empty ;; empty ;; empty
compiled_on_linux_gnu ;; empty ;; empty ;; empty ;; empty
cpu0_high ;; empty ;; empty ;; empty ;; empty
cpu0_low ;; empty ;; empty ;; empty ;; empty
cpu1_high ;; empty ;; empty ;; empty ;; empty
cpu1_low ;; empty ;; empty ;; empty ;; empty
cpu2_low ;; empty ;; empty ;; empty ;; empty
cpu3_low ;; empty ;; empty ;; empty ;; empty
cpu_high ;; empty ;; empty ;; empty ;; empty
Day30 ;; empty ;; empty ;; empty ;; empty
debian ;; empty ;; empty ;; empty ;; empty
debian_jessie ;; empty ;; empty ;; empty ;; empty
delta_reporting ;; empty ;; empty ;; empty ;; empty
diskfree_low ;; empty ;; empty ;; empty ;; empty
entropy_misc_in_low ;; empty ;; empty ;; empty ;; empty
entropy_misc_out_low ;; empty ;; empty ;; empty ;; empty
entropy_www_out_low ;; empty ;; empty ;; empty ;; empty
_etc_anacrontab_handle_efl_file_perms_files_positive_kept ;; efl_file_perms_files_positive ;; /etc/anacrontab ;; kept ;; nsa_rhel5 v4.2 sec 3.4.2
_etc_apt_preferences_d_cfengine_handle_efl_edit_template_files_perms_kept ;; efl_edit_template_files_perms ;; /etc/apt/preferences.d/cfengine ;; kept ;; Cfengine
_etc_apt_preferences_d_cfengine_handle_efl_edit_template_files_promiser_kept ;; efl_edit_template_files_promiser ;; /etc/apt/preferences.d/cfengine ;; kept ;; Cfengine
_etc_apt_sources_list_d_cfengine_community_list_handle_efl_edit_template_files_perms_kept ;; efl_edit_template_files_perms ;; /etc/apt/sources.list.d/cfengine-community.list ;; kept ;; Cfengine
_etc_apt_sources_list_d_cfengine_community_list_handle_efl_edit_template_files_promiser_kept ;; efl_edit_template_files_promiser ;; /etc/apt/sources.list.d/cfengine-community.list ;; kept ;; Cfengine
_etc_apt_sources_list_d_handle_efl_delete_files_files_isdir_kept ;; efl_delete_files_files_isdir ;; /etc/apt/sources.list.d ;; kept ;; Neil Watson
_etc_cron_daily_handle_efl_file_perms_files_recurse_with_base_postive_kept ;; efl_file_perms_files_recurse_with_base_postive ;; /etc/cron.daily ;; kept ;; nsa_rhel5 v4.2 sec 3.4.2
_etc_cron_d_handle_efl_file_perms_files_recurse_with_base_postive_kept ;; efl_file_perms_files_recurse_with_base_postive ;; /etc/cron.d ;; kept ;; nsa_rhel5 v4.2 sec 3.4.2
_etc_cron_hourly___handle_efl_file_perms_files_recurse_with_base_postive_kept ;; efl_file_perms_files_recurse_with_base_postive ;; /etc/cron.hourly/. ;; kept ;; nsa_rhel5 v4.2 sec 3.4.2
_etc_cron_monthly_handle_efl_file_perms_files_recurse_with_base_postive_kept ;; efl_file_perms_files_recurse_with_base_postive ;; /etc/cron.monthly ;; kept ;; nsa_rhel5 v4.2 sec 3.4.2
_etc_crontab_handle_efl_file_perms_files_positive_kept ;; efl_file_perms_files_positive ;; /etc/crontab ;; kept ;; nsa_rhel5 v4.2 sec 3.4.2
_etc_cron_weekly_handle_efl_file_perms_files_recurse_with_base_postive_kept ;; efl_file_perms_files_recurse_with_base_postive ;; /etc/cron.weekly ;; kept ;; nsa_rhel5 v4.2 sec 3.4.2
_etc_default_slapd_handle_efl_service_files_config_kept ;; efl_service_files_config ;; /etc/default/slapd ;; kept ;; Neil Watson
_etc_default_slapd_handle_efl_service_files_config_template_permissions_kept ;; efl_service_files_config_template_permissions ;; /etc/default/slapd ;; kept ;; Neil Watson
_etc_default_snmpd_handle_efl_service_files_config_template_kept ;; efl_service_files_config_template ;; /etc/default/snmpd ;; kept ;; snmp and opennms
_etc_default_snmpd_handle_efl_service_files_config_template_permissions_kept ;; efl_service_files_config_template_permissions ;; /etc/default/snmpd ;; kept ;; snmp and opennms
_etc_group_handle_efl_file_perms_files_positive_kept ;; efl_file_perms_files_positive ;; /etc/group ;; kept ;; nsa_rhel5 v4.2 sec 2.2.3.1
_etc_gshadow_handle_efl_file_perms_files_positive_kept ;; efl_file_perms_files_positive ;; /etc/gshadow ;; kept ;; nsa_rhel5 v4.2 sec 2.2.3.1
_etc_hosts_handle_efl_copy_files_remote_single_kept ;; efl_copy_files_remote_single ;; /etc/hosts ;; kept ;; Neil Watson
_etc_hosts_handle_efl_copy_files_single_perms_kept ;; efl_copy_files_single_perms ;; /etc/hosts ;; kept ;; Neil Watson
_etc_ldap_slapd_conf_handle_efl_service_files_config_kept ;; efl_service_files_config ;; /etc/ldap/slapd.conf ;; kept ;; Neil Watson
_etc_ldap_slapd_conf_handle_efl_service_files_config_template_permissions_kept ;; efl_service_files_config_template_permissions ;; /etc/ldap/slapd.conf ;; kept ;; Neil Watson
_etc_mailname_handle_efl_edit_template_files_perms_kept ;; efl_edit_template_files_perms ;; /etc/mailname ;; kept ;; email
_etc_mailname_handle_efl_edit_template_files_promiser_kept ;; efl_edit_template_files_promiser ;; /etc/mailname ;; kept ;; email
_etc_ntp_conf_handle_efl_service_files_config_template_kept ;; efl_service_files_config_template ;; /etc/ntp.conf ;; kept ;; Neil Watson
_etc_ntp_conf_handle_efl_service_files_config_template_permissions_kept ;; efl_service_files_config_template_permissions ;; /etc/ntp.conf ;; kept ;; Neil Watson
_etc_passwd_handle_efl_file_perms_files_positive_kept ;; efl_file_perms_files_positive ;; /etc/passwd ;; kept ;; nsa_rhel5 v4.2 sec 2.2.3.1
_etc_postfix_main_cf_handle_efl_service_files_config_template_kept ;; efl_service_files_config_template ;; /etc/postfix/main.cf ;; kept ;; email
_etc_postfix_main_cf_handle_efl_service_files_config_template_permissions_kept ;; efl_service_files_config_template_permissions ;; /etc/postfix/main.cf ;; kept ;; email
_etc_resolv_conf_handle_efl_edit_template_files_perms_kept ;; efl_edit_template_files_perms ;; /etc/resolv.conf ;; kept ;; Neil Watson
_etc_resolv_conf_handle_efl_edit_template_files_promiser_kept ;; efl_edit_template_files_promiser ;; /etc/resolv.conf ;; kept ;; Neil Watson
_etc_rsyslog_conf_handle_efl_service_files_config_kept ;; efl_service_files_config ;; /etc/rsyslog.conf ;; kept ;; Logging
_etc_rsyslog_conf_handle_efl_service_files_config_template_permissions_kept ;; efl_service_files_config_template_permissions ;; /etc/rsyslog.conf ;; kept ;; Logging
_etc_shadow_handle_efl_file_perms_files_positive_kept ;; efl_file_perms_files_positive ;; /etc/shadow ;; kept ;; nsa_rhel5 v4.2 sec 2.2.3.1
_etc_snmp_snmpd_conf_handle_efl_service_files_config_template_kept ;; efl_service_files_config_template ;; /etc/snmp/snmpd.conf ;; kept ;; snmp and opennms
_etc_snmp_snmpd_conf_handle_efl_service_files_config_template_permissions_kept ;; efl_service_files_config_template_permissions ;; /etc/snmp/snmpd.conf ;; kept ;; snmp and opennms
_etc_ssh_sshd_config_handle_efl_service_files_config_template_kept ;; efl_service_files_config_template ;; /etc/ssh/sshd_config ;; kept ;; Neil Watson
_etc_ssh_sshd_config_handle_efl_service_files_config_template_permissions_kept ;; efl_service_files_config_template_permissions ;; /etc/ssh/sshd_config ;; kept ;; Neil Watson
_etc_timezone_handle_efl_edit_template_files_perms_kept ;; efl_edit_template_files_perms ;; /etc/timezone ;; kept ;; Time
_etc_timezone_handle_efl_edit_template_files_promiser_kept ;; efl_edit_template_files_promiser ;; /etc/timezone ;; kept ;; Time
ettin2 ;; empty ;; empty ;; empty ;; empty
ettin2_watson_wilson_ca ;; empty ;; empty ;; empty ;; empty
ettin ;; empty ;; empty ;; empty ;; empty
ettin_watson_wilson_ca ;; empty ;; empty ;; empty ;; empty
Evening ;; empty ;; empty ;; empty ;; empty
fe80__21e_67ff_fe8b_f713 ;; empty ;; empty ;; empty ;; empty
fe80__fc54_ff_fe26_a02f ;; empty ;; empty ;; empty ;; empty
fe80__fc54_ff_fedd_5c07 ;; empty ;; empty ;; empty ;; empty
fe80__fc54_ff_feee_4bef ;; empty ;; empty ;; empty ;; empty
GMT_Hr0 ;; empty ;; empty ;; empty ;; empty
home ;; empty ;; empty ;; empty ;; empty
_home_neil__ssh_authorized_keys_handle_efl_edit_template_files_perms_kept ;; efl_edit_template_files_perms ;; /home/neil/.ssh/authorized_keys ;; kept ;; Neil Watson
_home_neil__ssh_authorized_keys_handle_efl_edit_template_files_promiser_kept ;; efl_edit_template_files_promiser ;; /home/neil/.ssh/authorized_keys ;; kept ;; Neil Watson
_home_neil__ssh_handle_efl_file_perms_files_recurse_with_base_postive_kept ;; efl_file_perms_files_recurse_with_base_postive ;; /home/neil/.ssh ;; kept ;; Neil Watson
Hr20 ;; empty ;; empty ;; empty ;; empty
Hr20_Q3 ;; empty ;; empty ;; empty ;; empty
ipp_in_high ;; empty ;; empty ;; empty ;; empty
ipp_out_high ;; empty ;; empty ;; empty ;; empty
ipv4_127_0_0_1 ;; empty ;; empty ;; empty ;; empty
ipv4_127_0_0 ;; empty ;; empty ;; empty ;; empty
ipv4_127_0 ;; empty ;; empty ;; empty ;; empty
ipv4_127 ;; empty ;; empty ;; empty ;; empty
ipv4_172_16_100_1 ;; empty ;; empty ;; empty ;; empty
ipv4_172_16_100 ;; empty ;; empty ;; empty ;; empty
ipv4_172_16 ;; empty ;; empty ;; empty ;; empty
ipv4_172 ;; empty ;; empty ;; empty ;; empty
July ;; empty ;; empty ;; empty ;; empty
Lcycle_1 ;; empty ;; empty ;; empty ;; empty
ldap_in_high ;; empty ;; empty ;; empty ;; empty
linux_3_12_1_amd64 ;; empty ;; empty ;; empty ;; empty
linux ;; empty ;; empty ;; empty ;; empty
linux_x86_64_3_12_1_amd64__1_SMP_Debian_3_12_9_1__2014_02_01_ ;; empty ;; empty ;; empty ;; empty
linux_x86_64_3_12_1_amd64 ;; empty ;; empty ;; empty ;; empty
linux_x86_64 ;; empty ;; empty ;; empty ;; empty
loadavg_high ;; empty ;; empty ;; empty ;; empty
localhost ;; empty ;; empty ;; empty ;; empty
localhost_localdomain ;; empty ;; empty ;; empty ;; empty
mac_00_1e_67_8b_f7_13 ;; empty ;; empty ;; empty ;; empty
messages_high_dev1 ;; empty ;; empty ;; empty ;; empty
messages_high_ldt ;; empty ;; empty ;; empty ;; empty
messages_low_normal ;; empty ;; empty ;; empty ;; empty
Min35_40 ;; empty ;; empty ;; empty ;; empty
Min39 ;; empty ;; empty ;; empty ;; empty
Min40_45 ;; empty ;; empty ;; empty ;; empty
Min44 ;; empty ;; empty ;; empty ;; empty
net_iface_br0 ;; empty ;; empty ;; empty ;; empty
net_iface_lo ;; empty ;; empty ;; empty ;; empty
not_nl ;; empty ;; empty ;; empty ;; empty
opennms_nodes ;; empty ;; empty ;; empty ;; empty
_opt_delta_reporting_app_DeltaR_pl_handle_efl_start_service_processes_proc_kept ;; efl_start_service_processes_proc ;; /opt/delta_reporting/app/DeltaR.pl ;; kept ;; delta reporting demo
_opt_delta_reporting_bin_dhlogmaker_handle_efl_copy_files_remote_single_kept ;; efl_copy_files_remote_single ;; /opt/delta_reporting/bin/dhlogmaker ;; kept ;; delta reporting
_opt_delta_reporting_bin_dhlogmaker_handle_efl_copy_files_single_perms_kept ;; efl_copy_files_single_perms ;; /opt/delta_reporting/bin/dhlogmaker ;; kept ;; delta reporting
otherprocs_high_dev1 ;; empty ;; empty ;; empty ;; empty
otherprocs_high ;; empty ;; empty ;; empty ;; empty
PK_MD5_49c0d7a71a9ae2003e20c28e40384a3b ;; empty ;; empty ;; empty ;; empty
postgres_in_high ;; empty ;; empty ;; empty ;; empty
postgres_out_high ;; empty ;; empty ;; empty ;; empty
Q3 ;; empty ;; empty ;; empty ;; empty
rootprocs_high ;; empty ;; empty ;; empty ;; empty
smtp_in_high ;; empty ;; empty ;; empty ;; empty
_srv_aux_backup_cf3_masterfiles___handle_efl_copy_files_recurse_perms_kept ;; efl_copy_files_recurse_perms ;; /srv/aux/backup/cf3/masterfiles/. ;; kept ;; cfengine
_srv_aux_backup_cf3_masterfiles___handle_efl_copy_files_remove_recurse_kept ;; efl_copy_files_remove_recurse ;; /etc/snmp/snmpd.conf ;; kept ;; snmp and opennms
_srv_aux_backup_cf3_masterfiles___handle_efl_copy_files_remove_recurse_kept ;; efl_copy_files_remove_recurse ;; /srv/aux/backup/cf3/masterfiles/. ;; kept ;; cfengine
_srv_aux_backup_cf3_masterfiles___handle_efl_copy_files_remove_recurse_repaired ;; efl_copy_files_remove_recurse ;; /etc/passwd ;; repaired ;; nsa_rhel5 v4.2 sec 2.2.3.1
_srv_aux_backup_cf3_masterfiles___handle_efl_copy_files_remove_recurse_repaired ;; efl_copy_files_remove_recurse ;; /srv/aux/backup/cf3/masterfiles/. ;; repaired ;; cfengine
_srv_aux_backup_cf3_sitefiles___handle_efl_copy_files_recurse_perms_kept ;; efl_copy_files_recurse_perms ;; /srv/aux/backup/cf3/sitefiles/. ;; kept ;; cfengine
_srv_aux_backup_cf3_sitefiles___handle_efl_copy_files_remove_recurse_kept ;; efl_copy_files_remove_recurse ;; /srv/aux/backup/cf3/sitefiles/. ;; kept ;; cfengine
ssh_in_high ;; empty ;; empty ;; empty ;; empty
ssh_out_low ;; empty ;; empty ;; empty ;; empty
_stdlib_has_path_apt_cache ;; empty ;; empty ;; empty ;; empty
_stdlib_has_path_apt_config ;; empty ;; empty ;; empty ;; empty
_stdlib_has_path_apt_get ;; empty ;; empty ;; empty ;; empty
_stdlib_has_path_aptitude ;; empty ;; empty ;; empty ;; empty
_stdlib_has_path_apt_key ;; empty ;; empty ;; empty ;; empty
_stdlib_has_path_awk ;; empty ;; empty ;; empty ;; empty
_stdlib_has_path_bc ;; empty ;; empty ;; empty ;; empty
_stdlib_has_path_cat ;; empty ;; empty ;; empty ;; empty
_stdlib_has_path_chkconfig ;; empty ;; empty ;; empty ;; empty
_stdlib_has_path_cksum ;; empty ;; empty ;; empty ;; empty
_stdlib_has_path_createrepo ;; empty ;; empty ;; empty ;; empty
_stdlib_has_path_crontab ;; empty ;; empty ;; empty ;; empty
_stdlib_has_path_crontabs ;; empty ;; empty ;; empty ;; empty
_stdlib_has_path_cut ;; empty ;; empty ;; empty ;; empty
_stdlib_has_path_dc ;; empty ;; empty ;; empty ;; empty
_stdlib_has_path_df ;; empty ;; empty ;; empty ;; empty
_stdlib_has_path_diff ;; empty ;; empty ;; empty ;; empty
_stdlib_has_path_dig ;; empty ;; empty ;; empty ;; empty
_stdlib_has_path_dmidecode ;; empty ;; empty ;; empty ;; empty
_stdlib_has_path_domainname ;; empty ;; empty ;; empty ;; empty
_stdlib_has_path_dpkg ;; empty ;; empty ;; empty ;; empty
_stdlib_has_path_echo ;; empty ;; empty ;; empty ;; empty
_stdlib_has_path_egrep ;; empty ;; empty ;; empty ;; empty
_stdlib_has_path_find ;; empty ;; empty ;; empty ;; empty
_stdlib_has_path_getfacl ;; empty ;; empty ;; empty ;; empty
_stdlib_has_path_grep ;; empty ;; empty ;; empty ;; empty
_stdlib_has_path_groupadd ;; empty ;; empty ;; empty ;; empty
_stdlib_has_path_hostname ;; empty ;; empty ;; empty ;; empty
_stdlib_has_path_ifconfig ;; empty ;; empty ;; empty ;; empty
_stdlib_has_path_init ;; empty ;; empty ;; empty ;; empty
_stdlib_has_path_ip ;; empty ;; empty ;; empty ;; empty
_stdlib_has_path_iptables ;; empty ;; empty ;; empty ;; empty
_stdlib_has_path_iptables_save ;; empty ;; empty ;; empty ;; empty
_stdlib_has_path_ls ;; empty ;; empty ;; empty ;; empty
_stdlib_has_path_netstat ;; empty ;; empty ;; empty ;; empty
_stdlib_has_path_perl ;; empty ;; empty ;; empty ;; empty
_stdlib_has_path_ping ;; empty ;; empty ;; empty ;; empty
_stdlib_has_path_printf ;; empty ;; empty ;; empty ;; empty
_stdlib_has_path_sed ;; empty ;; empty ;; empty ;; empty
_stdlib_has_path_service ;; empty ;; empty ;; empty ;; empty
_stdlib_has_path_sort ;; empty ;; empty ;; empty ;; empty
_stdlib_has_path_svc ;; empty ;; empty ;; empty ;; empty
_stdlib_has_path_sysctl ;; empty ;; empty ;; empty ;; empty
_stdlib_has_path_test ;; empty ;; empty ;; empty ;; empty
_stdlib_has_path_tr ;; empty ;; empty ;; empty ;; empty
_stdlib_has_path_update_alternatives ;; empty ;; empty ;; empty ;; empty
_stdlib_has_path_update_rc_d ;; empty ;; empty ;; empty ;; empty
_stdlib_has_path_useradd ;; empty ;; empty ;; empty ;; empty
_stdlib_path_exists_apt_cache ;; empty ;; empty ;; empty ;; empty
_stdlib_path_exists_apt_config ;; empty ;; empty ;; empty ;; empty
_stdlib_path_exists_apt_get ;; empty ;; empty ;; empty ;; empty
_stdlib_path_exists_apt_key ;; empty ;; empty ;; empty ;; empty
_stdlib_path_exists_awk ;; empty ;; empty ;; empty ;; empty
_stdlib_path_exists_bc ;; empty ;; empty ;; empty ;; empty
_stdlib_path_exists_cat ;; empty ;; empty ;; empty ;; empty
_stdlib_path_exists_chkconfig ;; empty ;; empty ;; empty ;; empty
_stdlib_path_exists_cksum ;; empty ;; empty ;; empty ;; empty
_stdlib_path_exists_crontab ;; empty ;; empty ;; empty ;; empty
_stdlib_path_exists_crontabs ;; empty ;; empty ;; empty ;; empty
_stdlib_path_exists_cut ;; empty ;; empty ;; empty ;; empty
_stdlib_path_exists_dc ;; empty ;; empty ;; empty ;; empty
_stdlib_path_exists_df ;; empty ;; empty ;; empty ;; empty
_stdlib_path_exists_diff ;; empty ;; empty ;; empty ;; empty
_stdlib_path_exists_dig ;; empty ;; empty ;; empty ;; empty
_stdlib_path_exists_dmidecode ;; empty ;; empty ;; empty ;; empty
_stdlib_path_exists_domainname ;; empty ;; empty ;; empty ;; empty
_stdlib_path_exists_dpkg ;; empty ;; empty ;; empty ;; empty
_stdlib_path_exists_echo ;; empty ;; empty ;; empty ;; empty
_stdlib_path_exists_egrep ;; empty ;; empty ;; empty ;; empty
_stdlib_path_exists_find ;; empty ;; empty ;; empty ;; empty
_stdlib_path_exists_getfacl ;; empty ;; empty ;; empty ;; empty
_stdlib_path_exists_grep ;; empty ;; empty ;; empty ;; empty
_stdlib_path_exists_groupadd ;; empty ;; empty ;; empty ;; empty
_stdlib_path_exists_hostname ;; empty ;; empty ;; empty ;; empty
_stdlib_path_exists_ifconfig ;; empty ;; empty ;; empty ;; empty
_stdlib_path_exists_init ;; empty ;; empty ;; empty ;; empty
_stdlib_path_exists_ip ;; empty ;; empty ;; empty ;; empty
_stdlib_path_exists_iptables ;; empty ;; empty ;; empty ;; empty
_stdlib_path_exists_iptables_save ;; empty ;; empty ;; empty ;; empty
_stdlib_path_exists_ls ;; empty ;; empty ;; empty ;; empty
_stdlib_path_exists_netstat ;; empty ;; empty ;; empty ;; empty
_stdlib_path_exists_perl ;; empty ;; empty ;; empty ;; empty
_stdlib_path_exists_ping ;; empty ;; empty ;; empty ;; empty
_stdlib_path_exists_printf ;; empty ;; empty ;; empty ;; empty
_stdlib_path_exists_sed ;; empty ;; empty ;; empty ;; empty
_stdlib_path_exists_service ;; empty ;; empty ;; empty ;; empty
_stdlib_path_exists_sort ;; empty ;; empty ;; empty ;; empty
_stdlib_path_exists_svc ;; empty ;; empty ;; empty ;; empty
_stdlib_path_exists_sysctl ;; empty ;; empty ;; empty ;; empty
_stdlib_path_exists_test ;; empty ;; empty ;; empty ;; empty
_stdlib_path_exists_tr ;; empty ;; empty ;; empty ;; empty
_stdlib_path_exists_update_alternatives ;; empty ;; empty ;; empty ;; empty
_stdlib_path_exists_update_rc_d ;; empty ;; empty ;; empty ;; empty
_stdlib_path_exists_useradd ;; empty ;; empty ;; empty ;; empty
syslog_high_dev1 ;; empty ;; empty ;; empty ;; empty
syslog_high_ldt ;; empty ;; empty ;; empty ;; empty
syslog_low_normal ;; empty ;; empty ;; empty ;; empty
temp1_high ;; empty ;; empty ;; empty ;; empty
temp2_high ;; empty ;; empty ;; empty ;; empty
temp3_high ;; empty ;; empty ;; empty ;; empty
_tmp_handle_efl_delete_files_files_isdir_kept ;; efl_delete_files_files_isdir ;; /tmp ;; kept ;; Neil Watson
_tmp___handle_efl_file_perms_files_positive_kept ;; efl_file_perms_files_positive ;; /tmp/. ;; kept ;; nsa_rhel5 v4.2 sec 2.2.3.2
toronto ;; empty ;; empty ;; empty ;; empty
users_low ;; empty ;; empty ;; empty ;; empty
_usr_lib_postfix_master_handle_efl_service_processes_proc_kept ;; efl_service_processes_proc ;; /usr/lib/postfix/master ;; kept ;; email
_usr_lib_postgresql_9__3_bin_postgres__D___handle_efl_start_service_processes_proc_kept ;; efl_start_service_processes_proc ;; /usr/lib/postgresql/9\.3/bin/postgres -D.* ;; kept ;; delta reporting demo
_usr_sbin_ntpd__p__var_run_ntpd_pid___handle_efl_service_processes_proc_kept ;; efl_service_processes_proc ;; /usr/sbin/ntpd -p /var/run/ntpd.pid.* ;; kept ;; Neil Watson
_usr_sbin_rsyslogd_handle_efl_service_processes_proc_kept ;; efl_service_processes_proc ;; /usr/sbin/rsyslogd ;; kept ;; Logging
_usr_sbin_slapd___handle_efl_service_processes_proc_kept ;; efl_service_processes_proc ;; /usr/sbin/slapd.* ;; kept ;; Neil Watson
_usr_sbin_snmpd__Lsd__Lf__dev_null__u_snmp__g_snmp__I__smux__p__var_run_snmpd_pid_handle_efl_service_processes_proc_kept ;; efl_service_processes_proc ;; /usr/sbin/snmpd -Lsd -Lf /dev/null -u snmp -g snmp -I -smux -p /var/run/snmpd.pid ;; kept ;; snmp and opennms
_usr_sbin_sshd_handle_efl_service_processes_proc_kept ;; efl_service_processes_proc ;; /usr/sbin/sshd ;; kept ;; Neil Watson
_usr_share_games_fortunes_taow_dat_handle_efl_copy_files_remote_single_kept ;; efl_copy_files_remote_single ;; /usr/share/games/fortunes/taow.dat ;; kept ;; Neil Watson
_usr_share_games_fortunes_taow_dat_handle_efl_copy_files_single_perms_kept ;; efl_copy_files_single_perms ;; /usr/share/games/fortunes/taow.dat ;; kept ;; Neil Watson
_usr_share_games_fortunes_taow_handle_efl_copy_files_remote_single_kept ;; efl_copy_files_remote_single ;; /usr/share/games/fortunes/taow ;; kept ;; Neil Watson
_usr_share_games_fortunes_taow_handle_efl_copy_files_single_perms_kept ;; efl_copy_files_single_perms ;; /usr/share/games/fortunes/taow ;; kept ;; Neil Watson
_var_cache_cfengine__etc_apt_preferences_d_cfengine_handle_efl_edit_template_cache_template_kept ;; efl_edit_template_cache_template ;; /var/cache/cfengine//etc/apt/preferences.d/cfengine ;; kept ;; Cfengine
_var_cache_cfengine__etc_apt_sources_list_d_cfengine_community_list_handle_efl_edit_template_cache_template_kept ;; efl_edit_template_cache_template ;; /var/cache/cfengine//etc/apt/sources.list.d/cfengine-community.list ;; kept ;; Cfengine
_var_cache_cfengine__etc_default_slapd_handle_efl_service_svc_cache_kept ;; efl_service_svc_cache ;; /var/cache/cfengine//etc/default/slapd ;; kept ;; Neil Watson
_var_cache_cfengine__etc_default_snmpd_handle_efl_service_svc_cache_kept ;; efl_service_svc_cache ;; /var/cache/cfengine//etc/default/snmpd ;; kept ;; snmp and opennms
_var_cache_cfengine__etc_ldap_slapd_conf_handle_efl_service_svc_cache_kept ;; efl_service_svc_cache ;; /var/cache/cfengine//etc/ldap/slapd.conf ;; kept ;; Neil Watson
_var_cache_cfengine__etc_mailname_handle_efl_edit_template_cache_template_kept ;; efl_edit_template_cache_template ;; /var/cache/cfengine//etc/mailname ;; kept ;; email
_var_cache_cfengine__etc_ntp_conf_handle_efl_service_svc_cache_kept ;; efl_service_svc_cache ;; /var/cache/cfengine//etc/ntp.conf ;; kept ;; Neil Watson
_var_cache_cfengine__etc_postfix_main_cf_handle_efl_service_svc_cache_kept ;; efl_service_svc_cache ;; /var/cache/cfengine//etc/postfix/main.cf ;; kept ;; email
_var_cache_cfengine__etc_resolv_conf_handle_efl_edit_template_cache_template_kept ;; efl_edit_template_cache_template ;; /var/cache/cfengine//etc/resolv.conf ;; kept ;; Neil Watson
_var_cache_cfengine__etc_rsyslog_conf_handle_efl_service_svc_cache_kept ;; efl_service_svc_cache ;; /var/cache/cfengine//etc/rsyslog.conf ;; kept ;; Logging
_var_cache_cfengine__etc_snmp_snmpd_conf_handle_efl_service_svc_cache_kept ;; efl_service_svc_cache ;; /var/cache/cfengine//etc/snmp/snmpd.conf ;; kept ;; snmp and opennms
_var_cache_cfengine__etc_ssh_sshd_config_handle_efl_service_svc_cache_kept ;; efl_service_svc_cache ;; /var/cache/cfengine//etc/ssh/sshd_config ;; kept ;; Neil Watson
_var_cache_cfengine__etc_timezone_handle_efl_edit_template_cache_template_kept ;; efl_edit_template_cache_template ;; /var/cache/cfengine//etc/timezone ;; kept ;; Time
_var_cache_cfengine__home_neil__ssh_authorized_keys_handle_efl_edit_template_cache_template_kept ;; efl_edit_template_cache_template ;; /var/cache/cfengine//home/neil/.ssh/authorized_keys ;; kept ;; Neil Watson
_var_cache_cfengine__var_spool_cron_crontabs_root_handle_efl_edit_template_cache_template_kept ;; efl_edit_template_cache_template ;; /var/cache/cfengine//var/spool/cron/crontabs/root ;; kept ;; Neil Watson
_var_cfengine_bin_cf_clean_handle_efl_copy_files_remote_single_kept ;; efl_copy_files_remote_single ;; /var/cfengine/bin/cf-clean ;; kept ;; Cfenigne
_var_cfengine_bin_cf_clean_handle_efl_copy_files_single_perms_kept ;; efl_copy_files_single_perms ;; /var/cfengine/bin/cf-clean ;; kept ;; Cfenigne
_var_cfengine_bin_cf_cron_handle_efl_copy_files_remote_single_kept ;; efl_copy_files_remote_single ;; /var/cfengine/bin/cf-cron ;; kept ;; Cfenigne
_var_cfengine_bin_cf_cron_handle_efl_copy_files_single_perms_kept ;; efl_copy_files_single_perms ;; /var/cfengine/bin/cf-cron ;; kept ;; Cfenigne
_var_cfengine_drop_ebackups_handle_efl_delete_files_files_isdir_kept ;; efl_delete_files_files_isdir ;; /var/cfengine/drop/ebackups ;; kept ;; Neil Watson
_var_cfengine_modules_cf_manifest_handle_efl_command_commands_repaired ;; efl_command_commands ;; /var/cfengine/modules/cf-manifest ;; repaired ;; efl_update cfengine
_var_cfengine_outputs_handle_efl_delete_files_files_isdir_kept ;; efl_delete_files_files_isdir ;; /var/cache/cfengine//var/spool/cron/crontabs/root ;; kept ;; Neil Watson
_var_cfengine_outputs_handle_efl_delete_files_files_isdir_kept ;; efl_delete_files_files_isdir ;; /var/cfengine/outputs ;; kept ;; Neil Watson
_var_cfengine_outputs_handle_efl_delete_files_files_isdir_repaired ;; efl_delete_files_files_isdir ;; /etc/timezone ;; repaired ;; Time
_var_cfengine_outputs_handle_efl_delete_files_files_isdir_repaired ;; efl_delete_files_files_isdir ;; /var/cfengine/outputs ;; repaired ;; Neil Watson
_var_spool_cron_crontabs_root_handle_efl_edit_template_files_perms_kept ;; efl_edit_template_files_perms ;; /var/spool/cron/crontabs/root ;; kept ;; Neil Watson
_var_spool_cron_crontabs_root_handle_efl_edit_template_files_promiser_kept ;; efl_edit_template_files_promiser ;; /var/spool/cron/crontabs/root ;; kept ;; Neil Watson
_var_tmp_handle_efl_delete_files_files_isdir_kept ;; efl_delete_files_files_isdir ;; /var/tmp ;; kept ;; Neil Watson
_var_tmp___handle_efl_file_perms_files_positive_kept ;; efl_file_perms_files_positive ;; /var/tmp/. ;; kept ;; nsa_rhel5 v4.2 sec 2.2.3.2
watson_wilson_ca ;; empty ;; empty ;; empty ;; empty
Wednesday ;; empty ;; empty ;; empty ;; empty
www_alt_in_high ;; empty ;; empty ;; empty ;; empty
www_out_low ;; empty ;; empty ;; empty ;; empty
x86_64 ;; empty ;; empty ;; empty ;; empty
Yr2014 ;; empty ;; empty ;; empty ;; empty
