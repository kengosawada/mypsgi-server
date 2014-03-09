use IO::Socket::INET;
use Data::Dumper;
use Plack::HTTPParser qw/parse_http_request/;
use Plack::Util;
use HTTP::Status qw/status_message/;
use App::Web;
use Plack::Middleware::Static;

my $listen = IO::Socket::INET->new(
    LocalAddr => "localhost",
    LocalPort => 9999,
    Proto     => "tcp",
    Listen    => 10,
    ReuseAddr => 1,
) or die $!;

$listen->listen or die $!;

my $req_times=0;
while ( my $conn = $listen->accept ) {
    $req_times++;
    print "req_times : $req_times\n";

    my $null_io = do { open my $io, "<", \"";$io};
    my $env = +{
	SERVER_PORT => '5000',
	SERVER_NAME => 'localhost',
	SCRIPT_NAME => '',
	REMOTE_ADDR => $conn->peerhost,
	'psgi.version' => [1, 1],
	'psgi.errors'  => *STDERR,
	'psgi.url_scheme' => 'http',
	'psgi.multiprocess' => Plack::Util::FALSE,
	'psgi.streaming'    => Plack::Util::FALSE,
	'psgi.nonblocking'  => Plack::Util::FALSE,
        'psgi.input'        => $null_io,
    };

    $conn->sysread( my $buf ,4096);
    my $reqlen = parse_http_request($buf, $env);

    my $app = App::Web->to_app();

    my $res = $app->($env);
    print Dumper $res->[0];

#    my @lines = ("HTTP/1.1 $res->[0] @{ [ status_message($res->[0]) ]}\015\012");
#    for (my $i =0; $i <  @{$res->[1]}; $i +=2){
#	push @lines, "$res->[1][$i]: $res->[1][$i + 1]\015\012";
#    }
    
#    push @lines, "Connection: close";
#    print Dumper $res->[0];
#    print Dumper status_message($res->[0]);
#    print Dumper $res->[1];
#    print Dumper join "", @lines;
#    $conn->syswrite(join "", @lines);

    Plack::Util::foreach ( $res->[2] ,sub {
	$conn->syswrite(shift);
    });
    
    $conn->close;
}

$listen->close;
