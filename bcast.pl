#!/usr/bin/perl
# bcast.pl copyright (c) 2018 andrew sveikauskas

use strict;

use Socket;
use Fcntl;
use Getopt::Long qw(GetOptions);

my $name;
my $server;
my $port = 1985;

GetOptions(
   "n=s" => \$name,
   "d"   => \$server,
   "p=i" => \$port
) or die "usage: $0 [-n name] [-p port] [-d]\n";

socket(FD, PF_INET, SOCK_DGRAM, getprotobyname('udp')) or die 'socket failed';

if ($server)
{
   my $addr = sockaddr_in($port, INADDR_ANY);
   bind(FD, $addr) or die 'bind';
   setsockopt(FD, SOL_SOCKET, SO_REUSEADDR, 1) or die 'SO_REUSEADDR';

   my $buf;
   while (my $remoteAddr = recv(FD, $buf, 4096, 0))
   {
      send(FD, "R:$name", 0, $remoteAddr) || die 'send';
   }
}
else
{
   my $addr = sockaddr_in($port, INADDR_BROADCAST);
   setsockopt(FD, SOL_SOCKET, SO_BROADCAST, 1) or die 'SO_BROADCAST';

   for (;;)
   {
      send(FD, "hello", 0, $addr) or die 'send';

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
            }
         }

         if ($ok) { last; }
         sleep(1);
      }

      fcntl(FD, F_SETFL, 0) or die 'fcntl';
   }
}

close FD;

