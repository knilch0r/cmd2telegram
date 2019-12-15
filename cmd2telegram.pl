#!/usr/bin/perl
# cmd2telegram.pl - telegram commandline tool.
# Copyright (C) 2018 Tobias 'knilch' Jordan
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; ONLY version 2 of the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

use strict;
use warnings;

use LWP::UserAgent;
use JSON;
use Config::Simple;
use Data::Dumper;
use URI::Encode;
use POSIX qw(strftime);

my $cfgfile = '.cmd2telegram';
if ($ARGV[0] eq '-c') {
	shift(@ARGV);
	$cfgfile = shift(@ARGV) // '';
}

my $cfg = new Config::Simple($cfgfile) || die "Can't open config '${cfgfile}': $!";
my $token = $cfg->param('token') || die "No token defined in config!";
my $user = $cfg->param('user') || die "No user defined in config!";
my $debug = $cfg->param('debug') // 0;

binmode STDIN, ":utf8";
binmode STDOUT, ":utf8";

sub telegram_request($) {
	my $method = shift;
	my $ua = LWP::UserAgent->new( agent => 'cmd2telegram ', ssl_opts => { verify_hostname => 1 } );
	$ua->env_proxy;
	my $response = $ua->get('https://api.telegram.org/bot'.$token.'/'.$method);
	if ($response->is_success) {
		print "response: ".$response->decoded_content."\n" if ($debug);
		my $json = decode_json($response->decoded_content);
		print Dumper($json)."\n" if ($debug);
		if (defined($json) && $json->{ok})
		{
			return $json->{result};
		} else {
			print "not ok: ".$response->decoded_content."\n";
		}
	} else {
	       	print "error: ".$response->status_line."\n";
	}
	return undef;
}

sub print_message($$) {
	# TODO: maybe use an extra parameter to specify what details to print?
	# TODO: for non-text messages, decode/download/show details?
	my $msg = shift;
	my $id = shift;
	return unless defined($msg->{date});
	return unless defined($msg->{chat});
	my $text;
	$text .= $id.' ';
	$text .= strftime("%Y-%m-%d %H:%M:%S ", localtime($msg->{date}));
	$text .= $msg->{chat}->{username} if defined($msg->{chat}->{username});
	$text .= '('.$msg->{chat}->{id}.')' if defined($msg->{chat}->{id});
	$text .= ' [sticker]' if defined($msg->{sticker});
	$text .= ' [audio]' if (defined($msg->{audio}) || defined($msg->{voice}));
	$text .= ' [photo]' if defined($msg->{photo});
	$text .= ' [video]' if (defined($msg->{video}) || defined($msg->{video_note}));
	$text .= ': ' if defined($msg->{text});
	$text .= ($msg->{text} // ' [no text]')."\n";
	print $text;
}

my $cmd = shift(@ARGV) // '';

if ($cmd eq 'status') {
	my $res =telegram_request('getMe');
	if (defined($res))
	{
		print "ok, bot id: ".$res->{id}.", name: ".$res->{first_name}."\n";
	}

} elsif ($cmd eq 'update') {
	my $start = shift(@ARGV);
	$start //= 0;
	my $result = telegram_request('getUpdates');
	if (defined($result)) {
		foreach my $res (@{$result})
		{
			my $msg = $res->{message};
			my $id = $res->{update_id};
			next unless (defined($id) && ($id > $start));
			print_message($msg, $id) if defined($msg);
		}
	}

} elsif ($cmd eq 'send') {
	my $chat = shift(@ARGV);
       	$chat //= $user;
	my $uri = URI::Encode->new({encode_reserved => 1});
	my @lines=<>;
	chomp(@lines);
	my $encoded = $uri->encode(join("\n", @lines));
	die("text too long, won't send") if (length($encoded) > 1024); # arbitrary value is arbitrary
	my $request = 'chat_id='.$chat.'&text='.$encoded;
	print "requesting: $request\n" if ($debug);
	telegram_request("sendMessage?$request");

} else {
	print "unsupported command: '$cmd'\n\n" if ($cmd);
	print "usage: $0 [-c cfg] command [parameters]\n\n";
	print "options:\n";
	print "\t-c cfg\tuse configuration file 'cfg' instead of .cmd2telegram\n\n";
	print "commands:\n";
	print "\tstatus\tchecks bot registration (getMe request)\n";
	print "\tupdate\tgets recent updates (getUpdates request)\n";
	print "\t      \tshows messages received by bot in telegram\n";
	print "\tsend  \tsends a text message (sendMessage request)\n";
	print "\t      \tparameter(s): chat id to send to (default: config)\n";
	print "\t      \tmessage is read from stdin\n";
}


