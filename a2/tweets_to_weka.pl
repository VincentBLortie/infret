#!/usr/bin/perl -w
use strict;
use diagnostics;

if (($#ARGV + 1) % 2 != 0) {
    print "Correct usage: tweets_to_weka.pl [tweets_file weka_file]+\n";
    die;
}

my @sets = ();
while (@ARGV) {
    my %set = ();
    $set{"tweets_file"} = shift(@ARGV);
    $set{"weka_file"} = shift(@ARGV);
    push @sets, \%set;
}

my %all_tokens = ();

foreach my $set (@sets) {
    print "READING ".$set->{"tweets_file"}."\n";
    my @tweets = ();
    $set->{"tweets"} = \@tweets;
    open SET_FILE, "<".$set->{"tweets_file"} or die "Could not open file '".$set->{"tweets_file"}."': $!\n";
    while(<SET_FILE>) {
        chomp;
        if (m/^([0-9]+)\t([0-9]+)\t\"(positive|negative|neutral|objective)\"\t(.*)$/) {
            my %tweet = ();
            push @tweets, \%tweet;

            $tweet{"sid"} = $1;
            $tweet{"uid"} = $2;
            $tweet{"sentiment"} = $3;
            $tweet{"text"} = $4;
            my @tweet_tokens = &extract_tokens($tweet{"text"});
            my %tweet_token_hash = ();
            $tweet{"token_hash"} = \%tweet_token_hash;
            foreach my $token (@tweet_tokens) {
                $tweet_token_hash{$token}++;
                $all_tokens{$token}++;
            }
        }
    }
    close SET_FILE;
    print "DONE READING ".$set->{"tweets_file"}."\n";
}

my @token_list = sort (keys %all_tokens);

foreach my $set (@sets) {
    print "WRITING ".$set->{"weka_file"}."\n";
    open SET_FILE, ">".$set->{"weka_file"} or die "Could not open file '".$set->{"weka_file"}."': $!\n";
    print SET_FILE '@RELATION token_rel\n';
    my $token_number = 1;
    foreach my $token (@token_list) {
        print SET_FILE '@ATTRIBUTE w'.$token_number.' NUMERIC\n';
        $token_number++;
    }
    foreach my $tweet (@{$set->{"tweets"}}) {
        my %tweet_tokens = %{$tweet->{"token_hash"}};
        foreach my $token (@token_list) {
            if (exists($tweet_tokens{$token})) {
                print SET_FILE $tweet_tokens{$token}.',';
            } else {
                print SET_FILE '0,';
            }
        }
        print SET_FILE $tweet->{"sentiment"}."\n";
    }
    close SET_FILE;
    print "DONE WRITING ".$set->{"weka_file"}."\n";
}

sub extract_tokens() {
    my ($entry_text) = @_;
    my $text = $entry_text;

    # Properly format the tweet text
    $text =~ s/&amp;/&/g;
    $text =~ s/&nbsp;/ /g;
    $text =~ s/&#039;/'/g;

    # Extract tokens from the tweet text
    my @tokens = ();

    # Hashtags
    while ($text =~ s/\#+\w+[\w\'-]*\w+/ /) {
        push @tokens, $&;
    }

    # Usernames
    while ($text =~ s/@+\w+/ /) {
        push @tokens, $&;
    }
    
    # URL
    while ($text =~ s/(https?:\/\/)[-\w]+(\.[-\w]+)*(:\d+)?(\/([~\w\+%-]|[,.;:][^\s])*)*(\?[\w\+%&=.;:-]+)?(\#[\w\-\.]*)?/ /) {
        push @tokens, $&;
    }

    # Smileys
    while ($text =~ s/([<>]?[:;=][o\*\'-]?([\(\)\[\]\{\}\/\\\|]\B|[dDpP])|[\(\)\[\]\{\}D\/\\\|][o\*\'-]?[:;=][<>]?\B)/ /) {
        push @tokens, $&;
    }
    
    # Words
    while ($text =~ s/[a-zA-Z]+(['-][a-zA-Z]+)*/ /) {
        push @tokens, $&;
    }

    # Hearts
    while ($text =~ s/<3/ /) {
        push @tokens, $&;
    }

    # Numbers
    while ($text =~ s/\d+%?/ /) {
        push @tokens, $&;
    }

    $text =~ s/ //g;
    push @tokens, split(//, $text);
    @tokens;
}
