#!/usr/bin/perl
use strict;
use warnings;

package dAmnPearl;

    use POSIX qw(strftime);
    use Digest::MD5 qw(md5_hex);
    use Time::HiRes qw(time);
    
    use feature "switch";
    
    require dAmnPacket;
    
    my $version     = '1.0';
    my $useragent   = "dAmnPearl v$version";
    my $author      = 'DivinityArcane <eittreim.justin@live.com>';
    my $date        = 'Wed October 31 2012 23:07';
    my $cwd         = '.';
    my $logdir      = "$cwd/logs";
    my $server      = 'chat.deviantart.com';
    my $port        = 3900;
    my $socket      = undef;
    my $username    = undef;
    my $password    = undef;
    my $authtoken   = undef;
    my $owner       = undef;
    my $trigger     = '!';
    my $connected   = 'TRUE';
    my $policebot   = 'botdom';
    my $start_time  = time;
    my $ping_sent   = 0;
    my @channels    = ();

    sub getAuthToken {
        # Define variables we'll be using
        my ($UA, $POST, $REQ, $RES, $TMP);
        
        # Include the needed modules
        use LWP::UserAgent;
        use HTTP::Cookies;
        
        # dA itself doesn't pass verification.
        $ENV{PERL_NET_HTTPS_SSL_SOCKET_CLASS} = "Net::SSL";
        $ENV{PERL_LWP_SSL_VERIFY_HOSTNAME} = 0;

        # We need a cookie jar so our login is persistant.
        $UA = LWP::UserAgent->new;
        $UA->cookie_jar(HTTP::Cookies->new( { } ));
        
        # Form valid POST data from the username and password.
        $POST =
            'ref=https%3A%2F%2Fwww.deviantart.com%2Fusers%2Floggedin'.
            '&username='. $username .'&password='. $password .'&remember_me=1';
            
        # We need to make a POST request to the login page first.
        $REQ = HTTP::Request->new(POST => "https://www.deviantart.com/users/login");
        $REQ->content_type('application/x-www-form-urlencoded');
        $REQ->content($POST);

        # Now, post the login data.
        $RES = $UA->request($REQ);
        
        # If the username or password was wrong, return null
        if ($RES->as_string =~ m/wrong-password/) {
            return undef;
        }
        
        # Now that we're logged in, get the working token from the chat page.
        $REQ = HTTP::Request->new(GET => "http://chat.deviantart.com/chat/Botdom");
        $RES = $UA->request($REQ);
        
        # Grab the token from all the madness.
        ($authtoken = join "", split /\n/, $RES->as_string) =~ s/.*dAmn_Login\([^,]*, "([^"]*)" \).*/$1/g;
    }
    
    sub init_connect {
        use IO::Socket;        
        # Let's get an authtoken
        
        if (-f "$cwd/authtoken.db") {
            out('CORE', 'Checking stored authtoken...');
            open(my $ATF, '<', "$cwd/authtoken.db")
                or die("Failed to read authtoken from file: $!");
                
            $authtoken = <$ATF>;
            chomp $authtoken;
            close $ATF;
        } else {
            out('CORE', 'No stored authtoken, getting one...');
            getAuthToken($username, $password);
            
            # Store it
            open(my $ATF, '>', "$cwd/authtoken.db")
                or die("Failed to write authtoken from file: $!");
                
            print $ATF $authtoken;
            close $ATF;
        }
        
        if (not defined $authtoken) {
            out('CORE', 'Failed to get an authtoken! Check your username/password.');
            exit;
        } else {
            out('CORE', 'We got an authtoken!');
        }
        
        out('CORE', 'Connecting to the server...');
        
        $socket = new IO::Socket::INET(
                    PeerAddr => "$server:$port",
                    Proto    => 'tcp',
                    Type     => SOCK_STREAM,
                    Blocking => 1) or die("Connect failed: $_\n");
                
        out('CORE', 'Connecting to dAmn at ' . $socket->peerhost() . ':' . $port);
        
        sendPacket("dAmnClient 0.3\nagent=$useragent\nauthor=$author");
        
        my $packet = '';
        my $char = '';
        
        while (defined $connected) {
            sysread($socket, $char, 1);
            if ($char eq "\0") {
                handle($packet);
                $packet = '';
            } else {
                $packet .= $char;
            }
        }
        
        close $socket;
        
        out('CORE', 'Disconnected abruptly. This shouldn\'t happen!');
    }
    
    sub handle {
        my %packet = dAmnPacket::parse(@_);
        
        if (defined($packet{body})) {
            $packet{body} = tablumps($packet{body});
        }
        
        given ($packet{command}) {
            when ('dAmnServer') {
                out('CORE', "Connected to dAmnServer $packet{parameter}");
                # Time to log in!
                sendPacket("login $username\npk=$authtoken");
            }
            
            when ('login') {
                if ($packet{arguments}{e} eq 'ok') {
                    out('CORE', "Logged in as $username [ok]");
                    # Time to autojoin :p
                    joinChannel('chat:datashare');
                    foreach (@channels) {
                        joinChannel(formatNS($_));
                    }
                } else {
                    out('CORE', "Failed to login: $packet{arguments}{e}");
                    out('CORE', 'Authtoken expired or password is wrong.');
                    unlink "$cwd/authtoken.db";
                    init_connect();
                    exit;
                }
            }
            
            when ('join') {
                if (lc $packet{parameter} eq 'chat:datashare') { return; }
                my $ns = formatNS($packet{parameter});
                if ($packet{arguments}{e} eq 'ok') {
                    out('CORE', "** Joined $ns [$packet{arguments}{e}]");
                } else {
                    out('CORE', "** Failed to join $ns [$packet{arguments}{e}]");
                }
            }
            
            when ('part') {
                if (lc $packet{parameter} eq 'chat:datashare') { return; }
                my $ns = formatNS($packet{parameter});
                if ($packet{arguments}{e} eq 'ok') {
                    out('CORE', "** Parted $ns [$packet{arguments}{e}]");
                } else {
                    out('CORE', "** Failed to part $ns [$packet{arguments}{e}]");
                }
            }
            
            when ('property') {
                if (lc $packet{parameter} eq 'chat:datashare') { return; }
                my $ns = formatNS($packet{parameter});
                out('CORE', "*** Got $packet{arguments}{p} for $ns");
                # No reason to store any of this at the moment.
            }
            
            when ('recv') {
                my $ns = formatNS($packet{parameter});
                my $cmd = $packet{subCommand};
                my $par = $packet{subParameter};
                given ($cmd) {
                    
                    when ('msg') {
                        my $from = $packet{arguments}{from};
                        my $msg = $packet{body};
                        if (lc $ns eq '#datashare') {
                            if (index ($msg, ':') != -1) {
                                my @bits = split /:/, lc $msg;
                                
                                if ($bits[0] eq 'bds') {
                                    given ($bits[1]) {
                                        
                                        when ("botcheck") {
                                            if (scalar @bits < 3) { return; }
                                            if (lc $from ne lc $policebot) { return; }
                                            if ($bits[2] eq 'all') {
                                                my $hash = lc md5_hex(lc $trigger . lc $from . lc $username);
                                                npsay($ns, "BDS:BOTCHECK:RESPONSE:$from,$owner,dAmnPearl,$version/0.3,$hash,$trigger");
                                            } elsif ($bits[2] eq 'direct' and lc $bits[3] eq lc $username) {
                                                my $hash = lc md5_hex(lc $trigger . lc $from . lc $username);
                                                npsay($ns, "BDS:BOTCHECK:RESPONSE:$from,$owner,dAmnPearl,$version/0.3,$hash,$trigger");
                                            }
                                        }
                                        
                                        when ("botdef") {
                                            if (scalar @bits < 4) { return; }
                                            if (lc $from ne lc $policebot) { return; }
                                            if ($bits[2] eq 'request' and lc $bits[3] eq lc $username) {
                                                my $hash = lc md5_hex(lc $from . 'damnpearldivinityarcane');
                                                npsay($ns, "BDS:BOTDEF:RESPONSE:$from,dAmnPearl,Perl,DivinityArcane,http://www.botdom.com/wiki/DAmnPearl,$hash");
                                            }
                                        }
                                        
                                        default {
                                            # Don't output this, because it'd be spammy.
                                            #out('CORE', "Unhandled BDS category: $bits[1]");
                                        }
                                    }
                                }
                            }
                        } else {
                            out($ns, "<$from> $msg");
                            
                            if ($msg eq 'Ping...' and lc $from eq lc $username and $ping_sent > 0) {
                                my $duration = sprintf "%.3f", time - $ping_sent;
                                say($ns, "Pong! <b><code>$duration second(s)</code></b>");
                                $ping_sent = 0;
                            }
                            
                            if (index(lc $msg, lc "$username: botcheck") != -1) {
                                if (lc $ns eq '#botdom' and lc $from eq 'botdom') {
                                    my $hash = lc md5_hex(lc $trigger . lc $from . lc $username);
                                    my $payload = lc "botresponse: $from $owner dAmnPearl $version/0.3 $hash $trigger";
                                    say($ns, "Beep-beep!<abbr title=\"$payload\"></abbr>");
                                    return;
                                }
                            }
                            
                            if (lc $msg eq lc "$username: trigcheck") {
                                    
                                say($ns, "$from: My trigger is <b><code>$trigger</code></b>");
                                return;
                            }
                            
                            my $trig = substr lc $msg, 0, length $trigger;
                            
                            if (substr($msg, 0, length $trigger) eq $trigger) {
                                my @args = split / /, substr $msg, length $trigger;
                                my $command = lc $args[0];
                                my $highlight = "<abbr title=\" $from \"></abbr>";
                                
                                given ($command) {
                                    
                                    when ('about') {
                                        my $uptime = uptime();
                                        say($ns, '<a href="http://www.botdom.com/wiki/DAmnPearl"><b><code>dAmnPearl</code></b></a> '.
                                            "version $version by :devDivinityArcane:<br/>&nbsp;&raquo;<b>Owner</b>: :dev$owner:<br/>".
                                            "&nbsp;&raquo;<b>Uptime</b>: $uptime $highlight");
                                    }
                                    
                                    when ('ping') {
                                        $ping_sent = time;
                                        say($ns, 'Ping...');
                                    }
                                    
                                    when ('commands') {
                                        say($ns, '<b>Commands available</b>:<br/>&nbsp;&middot;&nbsp; about &nbsp;&middot;&nbsp; '.
                                            "commands &nbsp;&middot;&nbsp; ping &nbsp;&middot;&nbsp; quit.$highlight");
                                    }
                                    
                                    when ('quit') {
                                        if (lc $from eq lc $owner) {
                                            my $uptime = uptime();
                                            say($ns, "Terminating. <code>[Uptime: $uptime]</code>");
                                            quit();
                                        }
                                    }
                                    
                                    default {
                                        out('CORE', "Unknown command: '$command'");
                                    }
                                }
                            }
                        }
                    }
                    
                    when ('action') {
                        if (lc $packet{parameter} eq 'chat:datashare') { return; }
                        my $from = $packet{arguments}{from};
                        my $msg = $packet{body};
                        out($ns, "* $from $msg");
                    }
                    
                    when ('join') {
                        if (lc $packet{parameter} eq 'chat:datashare') { return; }
                        out($ns, "** $par has joined.");
                    }
                    
                    when ('part') {
                        if (lc $packet{parameter} eq 'chat:datashare') { return; }
                        my $reason = '';
                        if (defined($packet{arguments}{r})) {
                            $reason = " ($packet{arguments}{r})";
                        }
                        out($ns, "** $par has left.$reason");
                    }
                    
                    when ('privchg') {
                        if (lc $packet{parameter} eq 'chat:datashare') { return; }
                        my $by = $packet{arguments}{by};
                        my $pc = $packet{arguments}{pc};
                        out($ns, "*** $par has been made a member of $pc by $by.");
                    }
                    
                    when ('kicked') {
                        if (lc $packet{parameter} eq 'chat:datashare') { return; }
                        my $by = $packet{arguments}{by};
                        my $reason = '';
                        if (defined($packet{body}) and length $packet{body} > 0) {
                            $reason = " ($packet{body})";
                        }
                        out($ns, "*** $par was kicked by $by$reason");
                    }
                    
                    when ('admin') {
                        if (lc $packet{parameter} eq 'chat:datashare') { return; }
                        given ($par) {
                            
                            when ('create') {
                                out($ns, "** $packet{arguments}{by} created privclass $packet{arguments}{name} with privs: $packet{arguments}{privs}");
                            }
                            
                            when ('update') {
                                out($ns, "** $packet{arguments}{by} updated privclass $packet{arguments}{name} with privs: $packet{arguments}{privs}");
                            }
                            
                            when ('rename') {
                                out($ns, "** $packet{arguments}{by} renamed privclass $packet{arguments}{prev} to $packet{arguments}{name}");
                            }
                            
                            when ('move') {
                                out($ns, "** $packet{arguments}{by} moved all members of privclass $packet{arguments}{prev} to $packet{arguments}{name}. $packet{arguments}{n} user(s) were affected.");
                            }
                            
                            when ('remove') {
                                out($ns, "** $packet{arguments}{by} removed privclass $packet{arguments}{name}. $packet{arguments}{n} user(s) were affected.");
                            }
                            
                            # No reason to parse SHOW and its subcommands for now.
                        }
                    }
                    
                    default {
                        out('CORE', "Unhandled RECV type from $ns: '$cmd'");
                    }
                }
            }
            
            when ('kicked') {
                if (lc $packet{parameter} eq 'chat:datashare') { return; }
                my $ns = formatNS($packet{parameter});
                my $reason = '';
                if (defined($packet{body}) and length $packet{body} > 0) {
                    $reason = " ($packet{body})";
                }
                out($ns, "** Kicked from $ns by $packet{arguments}{by}$reason");
                # Rejoin.
                joinChannel($ns);
            }
            
            when ('ping') {
                sendPacket('pong');
            }
            
            when ('send') {
                my $ns = formatNS($packet{parameter});
                out('CORE', "Failed to send to $ns: $packet{arguments}{e}");
            }
            
            when ('kick') {
                my $ns = formatNS($packet{parameter});
                out('CORE', "Failed to kick $packet{arguments}{u} in $ns: $packet{arguments}{e}");
            }
            
            when ('get') {
                my $ns = formatNS($packet{parameter});
                out('CORE', "Failed to get $packet{arguments}{p} in $ns: $packet{arguments}{e}");
            }
            
            when ('set') {
                my $ns = formatNS($packet{parameter});
                out('CORE', "Failed to set $packet{arguments}{p} in $ns: $packet{arguments}{e}");
            }
            
            when ('kill') {
                my $u = substr $packet{parameter}, 6;
                out('CORE', "Couldn't kill $u: $packet{arguments}{e}");
            }
            
            when ('disconnect') {
                out('CORE', "Disconnected: $packet{arguments}{e}");
                
                if ($packet{arguments}{e} eq 'ok') {
                    exit;
                } else {
                    out('CORE', 'Attempting to reconnect in 5 seconds...');
                    usleep(5000);
                    init_connect();
                }
            }
            
            default {
                out('CORE', "Unhandled dAmn packet: $packet{command}");
            }
        }
    }
    
    sub joinChannel {
        my $chan = $_[0];
        if (substr ($chan, 0, 1) eq '#') {
            $chan = formatNS($chan);
        }
        sendPacket("join $chan");
    }
    
    sub partChannel {
        my $chan = $_[0];
        if (substr ($chan, 0, 1) eq '#') {
            $chan = formatNS($chan);
        }
        sendPacket("part $chan");
    }
    
    sub say {
        my ($chan, $msg) = @_;
        if (substr ($chan, 0, 1) eq '#') {
            $chan = formatNS($chan);
        }
        sendPacket("send $chan\n\nmsg main\n\n$msg");
    }
    
    sub npsay {
        my ($chan, $msg) = @_;
        if (substr ($chan, 0, 1) eq '#') {
            $chan = formatNS($chan);
        }
        sendPacket("send $chan\n\nnpmsg main\n\n$msg");
    }
    
    sub act {
        my ($chan, $msg) = @_;
        if (substr ($chan, 0, 1) eq '#') {
            $chan = formatNS($chan);
        }
        sendPacket("send $chan\n\naction main\n\n$msg");
    }
    
    sub quit {
        sendPacket("disconnect");
    }
    
    sub sendPacket {
        my $payload = $_[0];
        print $socket "$payload\n\0";
    }
    
    sub formatNS {
        my $chan = $_[0];
        if (substr ($chan, 0, 1) eq '#') {
            return 'chat:' . substr $chan, 1;
        } else {
            return '#' . substr $chan, 5;
        }
    }
    
    sub timestamp {
        return strftime "[%H:%M:%S]", localtime;
    }
    
    sub monthstamp {
        strftime "%b-%Y", localtime;
    }
    
    sub daystamp {
        strftime "%d", localtime;
    }
    
    sub uptime {
        my $seconds = int(time - $start_time);
        my ($minutes, $hours) = (0, 0);
        my $uptime = '';
        
        while ($seconds >= 3600) {
            $hours++;
            $seconds -= 3600;
        }
        
        while ($seconds >= 60) {
            $minutes++;
            $seconds -= 60;
        }
        
        if ($hours > 0) {
            $uptime = "$hours hour" . ($hours == 1 ? ', ' : 's, ');
        }
        
        if ($minutes > 0) {
            $uptime .= "$minutes minute" . ($minutes == 1 ? ', ' : 's, ');
        }
        
        return $uptime . $seconds . ' seconds.';
    }
    
    sub tablumps {
        my $string = $_[0];
        
        # Dev links
        $string =~ s/&dev\t([^\t])\t([^\t]+)\t/:dev$2:/g;
        
        # Icons
        $string =~ s/&avatar\t([^\t]+)\t([^\t]+)\t/:icon$1:/g;
        
        # Abbr/Acronym
        $string =~ s/&(abbr|acro)\t([^\t]+)\t/<$1 title="$2">/g;
        
        # Links
        $string =~ s/&a\t([^\t]+)\t([^\t]*)\t/<a href="$1">/g;
        $string =~ s/&link\t([^\t]+)\t([^\t]+)\t([^\t]+)\t/<a href="$1">$2<\/a>/g;
        $string =~ s/&link\t([^\t]+)\t([^\t]+)\t/$1/g;
        
        # Images and IFrames
        $string =~ s/&(img|iframe)\t([^\t]+)\t([^\t]*)\t([^\t]+)\t/<$1 src="$2" \/>/g;
        
        # Don't think any other simple ones are supported?
        $string =~ s/&(|\/)(a|b|i|u|s|sup|sub|code|bcode|abbr|acro)\t/<$1$2>/g;
        
        # Breaks!
        $string =~ s/&br\t/<br\/>/g;
        
        # Thumbs
        $string =~ s/&thumb\t([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)\t/:thumb$1:/g;
        
        # Emotes
        $string =~ s/&emote\t([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)\t/$1/g;
        
        return $string;
    }
    
    sub out {
        my ($ns, $msg) = @_;
        print timestamp(), " [$ns] $msg\n";
        
        # Logging. Only log channels.
        if ((substr $ns, 0, 1) eq '#') {
            # File/folder prefixes.
            my $ms = monthstamp();
            my $ds = daystamp();
            # Make sure the log directory exists.
            unless (-d $logdir) {
                mkdir $logdir, 0777;
            }
            # Make sure we have a directory for the namespace.
            unless (-d "$logdir/$ns") {
                mkdir "$logdir/$ns", 0777;
            }
            # Make sure we have a directory for this month.
            unless (-d "$logdir/$ns/$ms") {
                mkdir "$logdir/$ns/$ms", 0777;
            }
            # Append [and create] the log file for today.
            open(my $fh, ">>", "$logdir/$ns/$ms/$ds-$ms.txt") 
                or die "Cannot open log file for writing: $!";
            print $fh timestamp(), " $msg\n";
        }
    }

    sub init {
       ($username, $password, $trigger, $owner, @channels) = @_;
       out('CORE', "dAmnPearl $version by DivinityArcane <eittreim.justin\@live.com>");
       out('CORE', "Built: $date");
       init_connect();
    }

1;
