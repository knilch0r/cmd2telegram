#!/usr/bin/perl
# telegram commandline tool.

use strict;
use warnings;

use LWP::UserAgent;
use JSON;
use Config::Simple;
use Data::Dumper;

my $cfgfile='.cmd2telegram';

my $cfg = new Config::Simple($cfgfile) || die "Can't open ${cfgfile}: $!";
my $token = $cfg->param('token') || die "No token defined in config!";
my $user = $cfg->param('user') || die "No user defined in config!";
my $debug = $cfg->param('debug') // 0;

my $ua = LWP::UserAgent->new( agent => 'cmd2telegram ', ssl_opts => { verify_hostname => 1 } );
$ua->env_proxy;

my $cmd = shift(@ARGV) // '';

if ($cmd eq 'status') {
	my $response = $ua->get('https://api.telegram.org/bot'.$token.'/getMe');
	if ($response->is_success) {
		print "response: ".$response->decoded_content."\n" if ($debug);
		my $json = decode_json($response->decoded_content);
		print Dumper($json)."\n" if ($debug);
		if (defined($json) && $json->{ok})
		{
			my $res = $json->{result};
			print "ok, bot id: ".$res->{id}.", name: ".$res->{first_name}."\n";
		} else {
			print "not ok: ".$response->decoded_content."\n";
		}
	} else {
	       	print "error: ".$response->status_line."\n";
	}
} elsif ($cmd eq 'update') {

} elsif ($cmd eq 'send') {

} else {
	print "unsupported command: '$cmd'\n\n" if ($cmd);
	print "usage: $0 command [parameters]\n\n";
	print "commands:\n";
	print "\tstatus\tchecks bot registration (getMe request)\n";
	print "\tupdate\tgets recent updates (getUpdates request)\n";
	print "\t      \t- shows messages sent to bot in telegram\n";
	print "\tsend  \tsends a text message (sendMessage request)\n";
	print "\t      \tparameter(s): message to send\n";
}
