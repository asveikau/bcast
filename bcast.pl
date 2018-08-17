#!/usr/bin/perl
# bcast.pl copyright (c) 2018 andrew sveikauskas

use strict;

use Socket;
use Socket qw(IPPROTO_IP);
use Fcntl;
use Getopt::Long qw(GetOptions);

my $name;
my $server;
my $port = 1985;

# Ugly hack to return all broadcast addrs by shelling out to
# ifconfig.  This is needed on platforms that won't use packets
# to 255.255.255.255 as a hint to send on all interfaces.
# (FreeBSD was the first such system tested.)
#
my $sys = $^O;
my $freebsd = ($sys eq "freebsd");
my $obsd = ($sys eq "openbsd");
my $windows = ($sys eq "msys");
my @freebsd_ifs;
sub addrs
{
   if ($freebsd || $obsd || $windows)
   {
      if (!scalar(@freebsd_ifs))
      {
         my $cmd = 'ifconfig';
         if ($windows)
         {
            $cmd = 'ipconfig';
         }
         my $a; my $b; my $c; my $d;
         open(P, "$cmd |");
         while (<P>)
         {
            chomp;

            my $addr;

            if ($windows)
            {
               if ($_ =~ /IPv4 Address.*: ([0-9.]*)/)
               {
                  $1 =~ /([0-9]*)\.([0-9]*)\.([0-9]*)\.([0-9]*)/;
                  $a = $1; $b = $2; $c = $3; $d = $4;
               }
               elsif ($_ =~ /Subnet Mask.*: ([0-9.]*)/)
               {
                  my $subnet = $1;
                  $subnet =~ /([0-9]*)\.([0-9]*)\.([0-9]*)\.([0-9]*)/;
                  $addr = ((~($1+0)) & 0xff | $a) . "." . 
                          ((~($2+0)) & 0xff | $b) . "." .
                          ((~($3+0)) & 0xff | $c) . "." .
                          ((~($4+0)) & 0xff | $d);
               }
            }
            elsif ($_ =~ /broadcast ([0-9.]*)/)
            {
               $addr = $1;
            }

            if (!($addr eq ''))
            {
               push @freebsd_ifs, inet_aton($addr);
            }
         }
         close P;
      }
      return @freebsd_ifs;
   }
   else
   {
      return (INADDR_BROADCAST);
   }
}

GetOptions(
   "n=s" => \$name,
   "d"   => \$server,
   "p=i" => \$port
) or die "usage: $0 [-n name] [-p port] [-d]\n";

socket(FD, PF_INET, SOCK_DGRAM, getprotobyname('udp')) or die 'socket failed';

if ($server)
{
   setsockopt(FD, SOL_SOCKET, SO_REUSEADDR, 1) or die 'SO_REUSEADDR';

   my $addr = sockaddr_in($port, INADDR_ANY);
   bind(FD, $addr) or die 'bind';

   my $buf;
   while (my $remoteAddr = recv(FD, $buf, 4096, 0))
   {
      send(FD, "R:$name", 0, $remoteAddr) || die 'send';
   }
}
else
{
   setsockopt(FD, SOL_SOCKET, SO_BROADCAST, 1) or die 'SO_BROADCAST';

   if ($freebsd)
   {
      my $IP_ONESBCAST = 0x17;
      setsockopt(FD, IPPROTO_IP, $IP_ONESBCAST, 1) or die 'IP_ONESBCAST';
   }

   for (;;)
   {
      foreach my $ip (addrs())
      {
         my $addr = sockaddr_in($port, $ip);
         send(FD, "hello", 0, $addr) or die 'send';
      }

      fcntl(FD, F_SETFL, O_NONBLOCK) or die 'fcntl';

      my $in = '';
      my $empty = '';
      vec($in, fileno(FD), 1) = 1;
      my $n = select($in, $empty, $empty, 1.0);

      if ($n == 1)
      {
         my $ok;

         my $buf;
         while (my $remoteAddr = recv(FD, $buf, 4096, 0))
         {
            my ($remotePort, $remoteIp) = unpack_sockaddr_in($remoteAddr);
            $remoteIp = inet_ntoa($remoteIp);

            if ($buf =~ /^R:$name$/)
            {
               print "$remoteIp\n";
               $ok = 1;
               last;
            }
         }

         if ($ok) { last; }
         sleep(1);
      }

      fcntl(FD, F_SETFL, 0) or die 'fcntl';
   }
}

close FD;

