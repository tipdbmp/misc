package http_async;

our ($VERSION, @ISA, @EXPORT, @EXPORT_OK);
BEGIN
{
    require Exporter;
    $VERSION   = 0.40;
    @ISA       = qw|Exporter|;
    @EXPORT    = qw|http_async|;
    @EXPORT_OK = qw||;
}

use strict;
use warnings;
use v5.14;
use AnyEvent::HTTP;
use Compress::Zlib;
use Encode;
use List::MoreUtils qw|any|;
use Encode;


my $only_once = 1;
my $EV;
sub http_async
{
    if ($only_once)
    {
        $only_once = 0;
        $EV = $main::EV;

        print <<'REQ'
[http_async] expects $main:EV to be defined and of type AnyEvent::CondVar;
    use http_async;
    ...
    'our $EV = AnyEvent->condvar;'
    ...
    http_async ...
    # =)
REQ
        and exit 1 if ref($EV) ne 'AnyEvent::CondVar';
        # say 'initing http_async';
    }

    my $method  = shift;
    my $url     = shift;
    my $on_data = shift;
    my %option  =
    (
        # default values
        timeout      => 10,
        cookie_jar   => {},
        on_error     => sub { },
        status_codes => [],
        params       => {},
        inflate      => 1,
        decode       => '',
        bytes        => 0,
        cookies_only => 0,

        # optional params
        %{ +shift // {} },
    );

    say "[http_async] expected a callback" and exit 1 if ref($on_data) ne 'CODE';

    my $params_string = '';
    my $params = $option{params};
    for my $param_name (keys %{ $params })
    {
        my $param_value = $params->{$param_name};
        $params_string .= "$param_name=$param_value&";
    }
    chop $params_string if $params_string ne '';
    $params_string = encode('UTF-8', $params_string);
    # say "\$params_string: !$params_string!";

    $option{header}{'Content-Type'} = 'application/x-www-form-urlencoded' if lc $method eq 'post';

    $EV->begin;
    http_request $method => $url,
    headers =>
    {
        # probably not the best defaults but...
        'User-Agent'      => 'Mozilla/5.0 (Windows NT 5.1; rv:8.0; en_us) Gecko/20100101 Firefox/8.0',
        'Accept'          => 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language' => 'en-us,en;q=0.5',
        'Accept-Encoding' => 'gzip, deflate',
        'DNT'             => '1',
        'Connection'      => 'keep-alive',

        %{ $option{header} // {} },
    },
    body       => $params_string,
    timeout    => $option{timeout},
    cookie_jar => $option{cookie_jar},
    sub
    {
        my ($content, $header) = @_;

        my $status = $header->{Status};
        if ($option{cookies_only})
        {
            $on_data->();
        }
        elsif ($status =~ /^2/ || (any { $status eq $_ } @{ $option{status_codes} }))
        {
            $content = Compress::Zlib::memGunzip($content) if $option{inflate} && !$option{bytes};

            if (!$option{bytes})
            {
                if ($option{decode} eq '') { $content = decode('UTF-8', $content); }
                else                       { $content = decode($option{decode}, $content); }
            }

            $on_data->($content, $url, $status);
        }
        else
        {
            my $reason = $header->{Reason};
            say "$status :: '$url' :: $reason";
            $option{on_error}->($url, $reason, $status);
        }

        $EV->end;
    };
}

1;
