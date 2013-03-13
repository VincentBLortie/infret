#!/usr/bin/perl -w
use strict;
use diagnostics;
$|++;

# 1: Sentiment classes will be balanced to have the same number of entries in the output file (extra entries for larger classes will be ignored)
# 0: No balancing of sentiment classes
my $balance_classes = 1;

# Check if number of arguments is valid
if (($#ARGV + 1) % 2 != 0) {
    print "Correct usage: tweets_to_weka.pl [tweets_file weka_file]+\n";
    die;
}

# Read every pair of arguments and store them as an element of the @sets array
# These pair specify two filenames for, respetively, the input tweet entry file and the output .arff weka file
my @sets = ();
while (@ARGV) {
    my %set = ();
    $set{"tweets_file"} = shift(@ARGV);
    $set{"weka_file"} = shift(@ARGV);
    push @sets, \%set;
}

# Count of the tokens found across all sets
my %all_tokens = ();

# Read each set and its tweets and store all of that info in a hash
foreach my $set (@sets) {
    # Record statistics about each set in a hash
    my %statistics = ("all" => 0, "positive" => 0, "negative" => 0, "neutral" => 0, "objective" => 0);
    $set->{"statistics"} = \%statistics;

    print "READING ".$set->{"tweets_file"}."\n";
    my @tweets = ();
    $set->{"tweets"} = \@tweets;
    open SET_FILE, "<".$set->{"tweets_file"} or die "Could not open file '".$set->{"tweets_file"}."': $!\n";
    while(<SET_FILE>) {
        chomp;
        # The following regex splits the entry into sid, uid, sentiment and tweet text
        if (m/^([0-9]+)\t([0-9]+)\t\"(positive|negative|neutral|objective)\"\t(.*)$/) {
            my %tweet = ();
            push @tweets, \%tweet;

            $tweet{"sid"} = $1;
            $tweet{"uid"} = $2;
            $tweet{"sentiment"} = $3;
            $statistics{$tweet{"sentiment"}}++;
            $statistics{"all"}++;
            $tweet{"text"} = $4;
            # Extract the tokens and put them in a hash table for quick and easy exists() checks
            my @tweet_tokens = &extract_tokens($tweet{"text"});
            my %tweet_token_hash = ();
            $tweet{"token_hash"} = \%tweet_token_hash;
            foreach my $token (@tweet_tokens) {
                $tweet_token_hash{$token}++;
                $all_tokens{$token}++;
            }
        } else {
            print "ERROR READING ".$set->{"tweets_file"}.": The following line is in the wrong format:\n$_\n";
        }
    }
    close SET_FILE;
    print "DONE READING ".$set->{"tweets_file"}."\n";
}

print "\n";

# Print out statistics for each set and record the class with the least amount of tweets
foreach my $set (@sets) {
    print "STATISTICS FOR '".$set->{"tweets_file"}." -> ".$set->{"weka_file"}."'\n";
    my $min_class = "all";
    if ($set->{"statistics"}->{"all"} > 0) {
        foreach my $sentiment (keys %{$set->{"statistics"}}) {
            if ($set->{"statistics"}->{$sentiment} < $set->{"statistics"}->{$min_class}) {
                $min_class = $sentiment;
            }
            print "'$sentiment': ".$set->{"statistics"}->{$sentiment}." (".sprintf("%.2f", (100.0 * $set->{"statistics"}->{$sentiment} / $set->{"statistics"}->{"all"}))."%)\n";
        } 
        print "minimum: $min_class\n";
        if ($balance_classes) {
            print "balanced total number of entries: " . (4*$set->{"statistics"}->{$min_class}) . " (" . sprintf("%.2f", (100.0 - (400.0*$set->{"statistics"}->{$min_class}/$set->{"statistics"}->{"all"}))) . "% loss)\n";
        } else {
            print "no balancing performed (all entries will be used)\n";
        }
    }
    $set->{"statistics"}->{"min"} = $set->{"statistics"}->{$min_class};
    print "\n";
}


# Ordered list of tokens. This order will be used in the arff files for the features
# TODO: Filter this list intelligently
my @token_list = ();
foreach my $candidate_token (sort (keys %all_tokens)) {
    if ($all_tokens{$candidate_token} > 1) {
        push @token_list, $candidate_token; 
    }
}

# Write the arff files
foreach my $set (@sets) {
    # Keep up a count of the number of entries written in each sentiment class
    my %written_count = ("positive" => 0, "negative" => 0, "neutral" => 0, "objective" => 0);

    my $tweet_count = 0;
    if ($balance_classes) {
        $tweet_count = $set->{"statistics"}->{"min"} * 4; 
    } else {
        $tweet_count = $set->{"statistics"}->{"all"}; 
    }

    print "WRITING ".$set->{"weka_file"}."\n";
    open SET_FILE, ">".$set->{"weka_file"} or die "Could not open file '".$set->{"weka_file"}."': $!\n";
    print SET_FILE "\@RELATION token_rel\n\n";
    # For the feature list, give each token a number and name it w# where # is that number
    my $token_number = 1;
    # Print the list of attributes
    foreach my $token (@token_list) {
        print SET_FILE "\@ATTRIBUTE w$token_number NUMERIC\n";
        $token_number++;
    }
    print SET_FILE "\@ATTRIBUTE sentiment {positive, negative, neutral, objective}\n\n";
    print SET_FILE "\@data\n";

    my $tweet_number = 0;
    print sprintf("%2d", (100.0 * $tweet_number / $tweet_count))."%";

    # Write all the tweets as comma-separated feature values
    foreach my $tweet (@{$set->{"tweets"}}) {
        my %tweet_tokens = %{$tweet->{"token_hash"}};
        # Only print the tweet if we haven't exceeded the limit for this tweet's sentiment or if we are not balancing sentiment classes
        if ($written_count{$tweet->{"sentiment"}} < $set->{"statistics"}->{"min"} or !$balance_classes) {
            print SET_FILE "{";
            my $t_i = 0;
            foreach my $token (@token_list) {
                if (exists($tweet_tokens{$token})) {
                    print SET_FILE "$t_i $tweet_tokens{$token}, ";
                }
                $t_i++;
            }
            print SET_FILE $t_i." ".$tweet->{"sentiment"}."}\n";
            $written_count{$tweet->{"sentiment"}}++;
            $tweet_number++;
            print "\r".sprintf("%2d", (100.0 * $tweet_number / $tweet_count))."%";
        }
    }
    close SET_FILE;
    print "\rDONE WRITING ".$set->{"weka_file"}."\n";
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
