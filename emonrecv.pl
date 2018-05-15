#!/usr/bin/perl

{
 package EmonRecv;
 
 use HTTP::Server::Simple::CGI;
 use base qw(HTTP::Server::Simple::CGI);
 use LWP::UserAgent;
 use IO::Socket::INET;


 
 my %dispatch = (
     '/input/post.json' => \&resp_recv_data,
 );

 sub writefile {
   my $filename = shift;
   my $d = shift;
   open(my $fh, '>>', $filename) or die "Could not open file '$filename' $!";
   print $fh $d;
   close $fh;
 }

 sub influx_udp_temp_send {
   my $node = shift ;
   my $values = shift;
   my $time = shift;
   my $influx_host = "10.0.0.2:5555";
   my $measurement = "emontemp";
   $| = 1;
   $values =~ s/{//g; 
   $values =~ s/}//g; 
   my @kvs = split(',',$values);
   my %probe_labels = ( 
                      1 => 'temp',
                      2 => 'ext_temp',
                      3 => 'humidity',
                      4 => 'battery',
                      );
   my $socket = new IO::Socket::INET (
                  PeerAddr   => $influx_host,
                  Proto      => 'udp') or die 
                  "ERROR in Socket Creation : $!\n"; 
   $socket->autoflush;
   foreach my $kv (@kvs) {
     my ($k,$v) = split(':',$kv);
     $socket->send("$measurement,node=$node,probe=$probe_labels{$k} value=$v $time\n");
   }
   my $foo = join('-',@kvs);
   #$socket->send("$measurement,node=$node,probe= value=$foo\n");
   $socket->close;
 }
 
 sub handle_request {
     my $self = shift;
     my $cgi  = shift;
   
     my $path = $cgi->path_info();
     my $handler = $dispatch{$path};
     my %temp_nodes = (
                      19 => 1,
                      20 => 1,
                      21 => 1, 
                      22 => 1, 
                      );
 
     if (ref($handler) eq "CODE") {
      print "HTTP/1.0 200 OK\r\n";
      # $handler->($cgi);
      my $node = $cgi->param('node');
      my $values = $cgi->param('json');
      my $time = $cgi->param('time') ;
      my $time = time();
      if ( $temp_nodes{$node} ) { 
        influx_udp_temp_send($node,$values,$time);   
      }
 #     writefile("/var/tmp/$i","$node,$values,$time");
      print "Content-type: application/json\n\n";
      print "ok";
         
     } else {
         print "HTTP/1.0 404 Not found\r\n";
         print $cgi->header,
               $cgi->start_html('Not found'),
               $cgi->h1('Not found'),
               $cgi->end_html;
     }
  }
} 
 
 # start the server on port 8080
 my $srv = EmonRecv->new(8080);
 $srv->run();
