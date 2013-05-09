#!/usr/bin/perl
use strictures;
use v5.14;
use AnyEvent;
use lib '..';
use http_async;
use List::Util qw|min max|;
use HTML::TreeBuilder;
use Encode;
use Text::CharWidth qw|mbswidth|;
use File::Slurp;


my $user_list_file = shift @ARGV // 'ytusers.txt';
my @user = map { trim($_) } grep { !/^\s*$/ } read_file($user_list_file);

our $EV = AnyEvent->condvar;
my @user_video;

# it's kinda of readable...
for my $user (@user)
{
    http_async get => "https://www.youtube.com/user/$user/videos?view=0", sub
    {
        my $content = shift;

        my $root_node = HTML::TreeBuilder->new_from_content($content);

        my $first_video = $root_node
            ->look_down(_tag => 'ul', id => 'channels-browse-content-grid')
            ->look_down(_tag => 'li', class => 'channels-content-item')
            ->look_down(_tag => 'span', class => 'context-data-item')
            ;

        my $video_name = $first_video
            ->look_down(_tag => 'span', class => 'content-item-detail')
            ->look_down(_tag => 'a')
            ->attr('title')
            ;
        $video_name = trim($video_name);

        my $video_link = $first_video
            ->look_down(_tag => 'span', class => 'content-item-detail')
            ->look_down(_tag => 'a')
            ->attr('href')
            ;

        # Old style...
        my $video_meta = $first_video
            ->look_down(_tag => 'span', class => 'content-item-detail')
            ->look_down(_tag => 'span', class => 'content-item-metadata')
            ->as_text
            ;

        my $video_views         = trim((split /\|/, $video_meta)[0]);
        my $video_uploaded_time = trim((split /\|/, $video_meta)[1]);

        push @user_video, [$user, $video_name, $video_views, $video_uploaded_time, $video_link];
    },
    {
        on_error => sub { my $url = shift; say "could not connect to '$url'"; }
    };
}

$EV->recv;

my $longest_user_length          = max map { ulength($_) } @user;
my $longest_title_length         = max map { ulength($_->[1]) } @user_video;
my $longest_views_length         = max map { ulength($_->[2]) } @user_video;
my $longest_uploaded_time_length = max map { ulength($_->[3]) } @user_video;

@user_video = sort sort_by_yt_uploaded_time @user_video;

for my $user_video (@user_video)
{
    my $user                = $user_video->[0];
    my $video_name          = $user_video->[1];
    my $video_views         = $user_video->[2];
    my $video_uploaded_time = $user_video->[3];
    my $video_link          = $user_video->[4];

    say encode('UTF-8',
       $user                 . ' ' x ($longest_user_length - ulength($user))
      . ' ' x 4
      . $video_name          . ' ' x ($longest_title_length - ulength($video_name)) # sprintf('%-*s', $longest_title_length, $video_name)
      . ' ' x 4
      . $video_views         . ' ' x ($longest_views_length - ulength($video_views))
      . ' ' x 4
      . $video_uploaded_time . ' ' x ($longest_uploaded_time_length - ulength($video_uploaded_time))
      . ' ' x 4
      .  "https://www.youtube.com$video_link"
      )
      ;
}

sub sort_by_yt_uploaded_time
{
    my %time_span_number =
    (
        minute  => 0,
        minutes => 0,
        hour    => 1,
        hours   => 1,
        day     => 2,
        days    => 2,
        week    => 3,
        weeks   => 3,
        month   => 4,
        months  => 4,
        year    => 5,
        years   => 5,
    );


    my $x = $a->[3];
    my $y = $b->[3];
    $x =~ s/\s+ago\s*//;
    $y =~ s/\s+ago\s*//;
    my ($x_number, $x_time_span) = split /\s+/, $x;
    my ($y_number, $y_time_span) = split /\s+/, $y;

    $x_time_span = $time_span_number{$x_time_span};
    $y_time_span = $time_span_number{$y_time_span};

    return $x_number <=> $y_number if $x_time_span == $y_time_span;
    return $x_time_span <=> $y_time_span;
}

sub trim
{
    my $str = shift;
    s/^\s+//, s/\s+$// for $str;
    return $str;
}

sub ulength { mbswidth shift }
