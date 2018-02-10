#!/usr/bin/perl -w
# filter for parts in MIME messages
# CAUTION: reads whole message from STDIN to memory, so don't feed big messages
use Email::MIME;

my $content = shift @ARGV;

unless (defined($content)) {
	print "usage:\n$0 content-type\n\n";
	print "example:\n$0 audio/x-wav < message > audio.wav\n\n";
	print "decodes STDIN as a MIME multipart message and outputs the first part\n";
	print "that matches the given content-type on STDOUT.\n";
	exit 1;
}

my @lines=<>;
my $message=join('',@lines);
my $parsed = Email::MIME->new($message);

# FIXME: should actually use the subparts method, and should recurse into more subparts
my @parts = $parsed->parts;
foreach my $part (@parts)
{
	# print "Content-Type: ".$part->content_type."\n";
	next unless $part->content_type eq $content;
	print $part->body;
	last;
}

