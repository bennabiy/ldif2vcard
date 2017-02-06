#!/usr/bin/perl -w
#=============================================================================
# Extract contacts from LDAP directory and create vCard files for iPod
# Modified for use with Citadel http://www.citadel.org
#=============================================================================
use strict;
use Net::LDAP::LDIF;
use MIME::Base64;
use Getopt::Long;
my %args = ();
GetOptions(\%args,
           "in=s",
           "out=s"
           ) or die "Invalid arguments!";
die "Missing -in!" unless $args{in};
die "Missing -out!" unless $args{out};

# INPUT PARAMETERS
my $LDIFFILE = $args{in};
my $OUTNAME = $args{out};
my $OUTPUTDIR = "./";

my $VCARDEXT = "vcf";

# LDAP -> VCARD
# fn -The contact's formatted name (how it is sorted)
# n - The contact's name as it appears in the Contact
# adr & add - The contact's address(es)
# tel - The contact's telephone number(s)
# email - The contact's email address
# title - The contact's title
# org - The contact's company name
# url - The contact's Web address
# note - Notes on the contact

my %FIELDMAP = (
    "displayName"              => "fn",
    "cn"                       => "n",
    "facsimileTelephoneNumber" => "tel;type=fax",
    "telephoneNumber"          => "tel;type=work",
    "mobile"                   => "tel;type=cell",
    "homePhone"                => "tel;type=home",
    "title"                    => "title",
    "o"                        => "org",
    "givenName"                => "nickname",
    "url",                     => "url",
    "description"              => "note"
);


# Counters
my $ENTRYCOUNT = 0;


main();


#-------------------------------------------------------------------------
# initialization routines
#
sub main
{
    ldif2vcard_main();
}


#-------------------------------------------------------------------------
# this is where the real work gets done
#
sub ldif2vcard_main
{
    printf(STDERR "Reading LDIF [%s]\n", $LDIFFILE);
    my $ldif = Net::LDAP::LDIF->new( $LDIFFILE, "r",
                                       onerror => 'undef' );
    while( not $ldif->eof() ) {
        my $entry = $ldif->read_entry();
        if ( $ldif->error() ) {
            printf(STDERR "Error msg: %s\n", $ldif->error());
            printf(STDERR "Error lines:\n%s\n", $ldif->error_lines());
        } else {

            my $vcffile = sprintf("%s.%s", $OUTNAME,
                                                $VCARDEXT);
            $vcffile =~ s/ /_/g;
            $vcffile = sprintf("%s/%s", $OUTPUTDIR, $vcffile);
            # printf(STDOUT "vCard: %s\n", $vcffile);

            open(VCF, ">> $vcffile") || die("unable to open $vcffile");

            printf(VCF "begin:vcard\nversion:3.0\n");

            # Simple field copy attributes
            for my $key ( keys %FIELDMAP ) {
                if ($entry->exists($key)) {
                    printf(VCF "%s:%s\n", $FIELDMAP{$key},
                                          $entry->get_value($key) );
                }
            }

            # Special Case Attributes Handled Here
            if ( $entry->exists('postalAddress') ||
                 $entry->exists('l') ||
                 $entry->exists('st') ||
                 $entry->exists('postalCode') ) {
                printf(VCF "adr;type=work,postal,parcel:%s;%s;%s;%s;%s;%s\n",
                       "", "",
                       $entry->exists('postalAddress') ? $entry->get_value('postalAddress') : "",
                       $entry->exists('l') ? $entry->get_value('l') : "",
                       $entry->exists('st') ? $entry->get_value('st') : "",
                       $entry->exists('postalCode') ? $entry->get_value('postalCode') : "");
            }

            if ($entry->exists('homePostalAddress')) {
                my @toks = split(/\$/, $entry->get_value('homePostalAddress'), 4);
                my @cityst = split(/,/, $toks[1], 2);

                printf(VCF "adr;type=home,postal,parcel:%s;%s;%s;%s;%s;%s\n",
                           "", "",
                           defined($toks[0]) ? $toks[0] : "",
                           defined($cityst[0]) ? $cityst[0] : "",
                           defined($cityst[1]) ? $cityst[1] : "",
                           defined($toks[2]) ? $toks[2] : "");
            }

            if ($entry->exists('mail')) {
                my @values = $entry->get_value('mail');
                foreach(@values) {
                    printf(VCF "email;internet:%s\n", $_);
                }
            }

            if ($entry->exists('jpegPhoto')) {
                 printf(VCF "photo;type=jpeg;encoding=base64:\n");
                 my $encoded = encode_base64($entry->get_value('jpegPhoto'));

                 my @picarray = split (/\n/, $encoded );
                 for (my $xc=0; $xc<@picarray; $xc++)
                 {
                     printf(VCF " %s\n", $picarray[$xc]);
                 }
            }

            printf(VCF "end:vcard\n\n");
            close(VCF);
            $ENTRYCOUNT++;
        }
    }
    $ldif->done();

    printf(STDOUT "Number of Entries: %d\n", $ENTRYCOUNT);
}


#-------------------------------------------------------------------------
sub print_hash
{
    my $hashref = shift();
    my %lochash = %$hashref;
    while( my ($k, $v) = each %lochash) { print "$k => $v\n"; }
}


#-------------------------------------------------------------------------
sub usage
{
    printf(STDOUT "usage: %s -in file.ldif -out name\n", $0);
    printf(STDOUT "Note: -out name will have .vcf appended automatically.")
}


__END__

=pod

=head1 NAME

ldif2vcard - create Citadel vCard files from an LDIF file

=head1 SYNOPSIS

B<ldif2vcard.pl>

=head1 DESCRIPTION

B<ldif2vcard> will create one vCard [RFC2426] file from each entry
that it reads from the LDIF file.  This file will be optimized for
the Citadel, meaning that it will only contain information that the
Citadel is capable of displaying.  Please be advised, this is not a
general purpose vCard generation tool.

=head1 VARIABLES

=over

=item $LDIFFILE <filename>

Indicate the name of the LDIF file.

=item $OUTPUTDIR <directory>

Sets vCard output directory.

=back

=head1 BUGS

No known bugs.  Please send bug reports to author.

=head1 AUTHOR

Adam Kaufman <adam_kaufman@yahoo.com>

=head1 LICENSE

Copyright (c) 2007, Adam D. Kaufman All rights reserved.
Copyright (c) 2017, ben-Nabiy Derush All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions
are met:

=over

=item 1. Redistributions of source code must retain the above copyright
notice, this list of conditions and the following disclaimer.

=item 2. Redistributions in binary form must reproduce the above
copyright notice, this list of conditions and the following disclaimer
in the documentation and/or other materials provided with the
distribution.

=item 3. Neither the name of the author nor the names of its
contributors may be used to endorse or promote products derived from
this software without specific prior written permission.

=back

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
HOLDERS OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

=cut
