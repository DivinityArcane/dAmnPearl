# Perl dAmnPacket parser - Part of dAmnPearl
# Author: Justin Eittreim <eittreim.justin@live.com>
# Date: Wed Oct 31 2012 23:59

package dAmnPacket;
    sub parse {
        my $packet = $_[0];
        my %self = ();
        
        $self{command} = '';
        $self{parameter} = '';
        $self{subCommand} = '';
        $self{subParameter} = '';
        $self{body} = '';
        $self{raw} = '';
        $self{arguments} = ();
            
        $packet =~ s/\0//;
        
        ($self{raw} = $packet) =~ s/\n/\\n/;
        
        my $nl_pos = index($packet, "\n");
        my $chunk = substr $packet, 0, $nl_pos;
        
        if ((my $space_pos = index($packet, ' ')) != -1) {
            $self{command} = substr $chunk, 0, $space_pos;
            $self{parameter} = substr $chunk, $space_pos + 1;
        } else {
            $self{command} = $chunk;
        }
        
        $packet = substr $packet, $nl_pos + 1;
            
        if ((my $nlnl_pos = rindex($packet, "\n\n")) != -1) {
            $self{body} = substr $packet, $nlnl_pos + 2;
            $packet = substr $packet, 0, $nlnl_pos;
        }
        
        my @chunks = split /\n/, $packet;
        foreach my $piece (@chunks) {
            if (length $piece > 0) {
                if ((my $sep_pos = index($piece, '=')) != -1) {
                    $self{arguments}{substr $piece, 0, $sep_pos} = substr $piece, $sep_pos + 1;
                } else {
                    if (($space_pos = index($packet, ' ')) != -1) {
                        $self{subCommand} = substr $piece, 0, $space_pos - 1;
                        $self{subParameter} = substr $piece, $space_pos;
                    } else {
                        $self{subCommand} = $piece;
                    }
                }
            }
        }
        
        return %self;
    }
    
1;
