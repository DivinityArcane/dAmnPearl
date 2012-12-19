#!/bin/sh
echo "Installing deps...\n"
perl -MCPAN -e 'my @mods = qw(Crypt::SSLeay LWP::UserAgent); foreach my $mod (@mods) { print "Trying to 
install $mod...\n"; CPAN::install($mod); }'
read -p "Done! Hit enter/return to close this window";
