#!/usr/bin/env perl

# postfix queue/s size
# source: http://tech.groups.yahoo.com/group/postfix-users/message/255133

use strict;
use warnings;
use Symbol;
use Getopt::Long;

sub count($);
sub exit_ok($);
sub exit_warn($);
sub exit_crit($);
sub exit_unknown;

my $STATE_OK = 0;
my $STATE_WARN = 1;
my $STATE_CRIT = 2;
my $STATE_UNKNOWN = 3;

my $noise = 5;
my $crit = 0;
my $warn = 5;
my $sleep = 30;
my $queue = "active";

GetOptions("noise=i" => \$noise,
           "crit=i" => \$crit,
           "warn=i" => \$warn,
           "sleep=i" => \$sleep,
           "queue=s" => \$queue) or die("Error in command line arguments\n");

my $qdir = `postconf -h queue_directory`;
chomp($qdir);
chdir($qdir) or die "$0: chdir: $qdir: $!\n";

my $size1 = count($queue);
if ($size1 < $noise)
{
  exit_ok({msg => "'$queue' queue is under threshold", size => $size1});
}
else
{
  sleep $sleep;
  my $size2 = count($queue);
  my $rate = $size1 - $size2;
  if ($rate <= $crit)
  {
    exit_crit({msg => "'$queue' queue is processing less than $crit messages in $sleep seconds", size => $size2});
  }
  elsif ($rate <= $warn)
  {
    exit_warn({msg => "'$queue' queue is processing less than $crit messages in $sleep seconds", size => $size2});
  }
  else
  {
    exit_ok({msg => "'$queue' queue is processing acceptably fast", size => $size2});
  }
}


#printf "Incoming: %d\n", count("incoming");
#printf "Active: %d\n", count("active");
#printf "Deferred: %d\n", count("deferred");
#printf "Bounced: %d\n", count("bounce");
#printf "Hold: %d\n", count("hold");
#printf "Corrupt: %d\n", count("corrupt");

# count returns the number of messages in the given queue
# It will fail in Postfix 2.9+ when enable_long_queue_ids=yes
# So if we upgrade Postfix and use long queue id's we'll need some new regex
sub count($)
{
  my ($dir) = @_;
  my $dh = gensym();
  my $c = 0;
  opendir($dh, $dir) || exit_unknown({msg => "'$queue' queue does not exit"});
  while (my $f = readdir($dh)) 
  {
    if ($f =~ m{^[A-F0-9]{5,}$})
    {
      ++$c;
    }
    elsif ($f =~ m{^[A-F0-9]$})
    {
      $c += count("$dir/$f");
    }
  }
  closedir($dh) || exit_unknown({msg => "'$queue' queue may have vanished"});
  return $c;
}

# exit_* all print the status and provided message and exit with the appropriate Nagios return code
sub exit_ok($)
{
  my $ref = shift;
  my $msg = $ref->{msg};
  my $size = $ref->{size};

  print "OK: $msg. Queue size is $size\n";
  exit $STATE_OK;
}

sub exit_crit($)
{
  my $ref = shift;
  my $msg = $ref->{msg};
  my $size = $ref->{size};

  print "CRITICAL: $msg. Queue size is $size\n";
  exit $STATE_CRIT;
}

sub exit_warn($)
{
  my $ref = shift;
  my $msg = $ref->{msg};
  my $size = $ref->{size};

  print "WARNING: $msg. Queue size is $size\n";
  exit $STATE_WARN;
}

sub exit_unknown
{
  my $ref = shift;
  my $msg = $ref->{msg};

  print "UNKNOWN: $msg\n";
  exit $STATE_UNKNOWN;
}
