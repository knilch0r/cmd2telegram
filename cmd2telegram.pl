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
if (($ARGV[0] // '') eq '-c') {
	shift(@ARGV);
	$cfgfile = shift(@ARGV) // '';
}

my $cfg = new Config::Simple($cfgfile) || die "Can't open config '${cfgfile}': $!";
my $token = $cfg->param('token') || die "No token defined in config!";
my $user = $cfg->param('user') || die "No user defined in config!";
my $debug = $cfg->param('debug') // 0;

binmode STDIN, ":utf8";
binmode STDOUT, ":utf8";

sub handleresponse($) {
	my $response = shift;
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

sub telegram_request($) {
	my $method = shift;
	my $ua = LWP::UserAgent->new( agent => 'cmd2telegram ', ssl_opts => { verify_hostname => 1 } );
	$ua->env_proxy;
	my $response = $ua->get('https://api.telegram.org/bot'.$token.'/'.$method);
	return handleresponse($response);
}

sub telegram_sendfile($$$$) {
	my ($filename, $method, $caption, $chatid) = @_;
	my $ua = LWP::UserAgent->new( agent => 'cmd2telegram ', ssl_opts => { verify_hostname => 1 } );
	$ua->env_proxy;
	my $response = $ua->post('https://api.telegram.org/bot'.$token.'/send'.ucfirst($method),
	                         Content_Type    => 'form-data',
	                         Content         => [ chat_id => $chatid,
	                                              caption => $caption,
	                                              $method => [ $filename ]
	                                            ]
	                        );
	return handleresponse($response);
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
	my $start = shift(@ARGV) // '';
	my $timeout = shift(@ARGV) // '';
	$timeout = '&timeout='.$timeout if ($timeout);
	my $result = telegram_request('getUpdates?offset='.$start.$timeout);
	if (defined($result)) {
		foreach my $res (@{$result})
		{
			my $msg = $res->{message};
			my $id = $res->{update_id};
			next unless defined($id);
			print_message($msg, $id) if defined($msg);
		}
	}

} elsif ($cmd eq 'send') {
	my $chat = shift(@ARGV) // $user;
	my $uri = URI::Encode->new({encode_reserved => 1});
	my @lines=<>;
	chomp(@lines);
	my $encoded = $uri->encode(join("\n", @lines));
	die("text too long, won't send") if (length($encoded) > 1024); # arbitrary value is arbitrary
	my $request = 'chat_id='.$chat.'&text='.$encoded;
	print "requesting: $request\n" if ($debug);
	telegram_request("sendMessage?$request");

} elsif ($cmd eq 'sendfile') {
	my $file = shift(@ARGV);
	die("usage: $0 sendfile filename [method] [caption] [chat]") unless ($file);
	die("file '$file' not a readable file") unless ((-r $file) && (-f $file));
	my $method = shift(@ARGV) // 'photo';
	my $caption = shift(@ARGV) // '';
	my $chat = shift(@ARGV) // $user;
	print "sending '$file' using method '$method' to chat '$chat'\ncaption '$caption'\n" if ($debug);
	telegram_sendfile($file, $method, $caption, $chat);

} else {
	print "unsupported command: '$cmd'\n\n" if ($cmd);
	print "usage: $0 [-c cfg] command [parameters]\n\n";
	print "options:\n";
	print "\t-c cfg\tuse configuration file 'cfg' instead of .cmd2telegram\n\n";
	print "commands:\n";
	print "\tstatus  \tchecks bot registration (getMe request)\n";
	print "\tupdate  \tgets recent updates (getUpdates request)\n";
	print "\t        \tshows messages received by bot in telegram\n";
	print "\t        \tparameter(s): offset timeout\n";
	print "\t        \t\toffset  \tmessage offset (default empty)\n";
	print "\t        \t\ttimeout \ttimeout for longpoll (default empty)\n";
	print "\tsend    \tsends a text message (sendMessage request)\n";
	print "\t        \tparameter: chat\n";
	print "\t        \t\tchat    \tchat id to send to (default: config)\n";
	print "\t        \tmessage is read from stdin\n";
	print "\tsendfile\tsends a file (sendPhoto/sendAudio/... request)\n";
	print "\t        \tparameter(s): filename method caption chat\n";
	print "\t        \t\tfilename\tfile to send (mandatory)\n";
	print "\t        \t\tmethod  \tkind of file (default: 'photo')\n";
	print "\t        \t\tcaption \tcaption to use (default: empty)\n";
	print "\t        \t\tchat    \tchat id to send to (default: config)\n";
}

