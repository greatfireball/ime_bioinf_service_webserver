package BioInf::ServiceWS::Translate;
#use Dancer2;

use LWP::UserAgent;
use HTTP::Request::Common;
use Data::Dumper;

#set serializer => 'JSON';

# got the following matrix from https://www.kazusa.or.jp/codon/cgi-bin/showcodon.cgi?species=83333&aa=11&style=N
our $matrix =
    q/UUU F 0.57 19.7 (   101)  UCU S 0.11  5.7 (    29)  UAU Y 0.53 16.8 (    86)  UGU C 0.42  5.9 (    30)
UUC F 0.43 15.0 (    77)  UCC S 0.11  5.5 (    28)  UAC Y 0.47 14.6 (    75)  UGC C 0.58  8.0 (    41)
UUA L 0.15 15.2 (    78)  UCA S 0.15  7.8 (    40)  UAA * 0.64  1.8 (     9)  UGA * 0.36  1.0 (     5)
UUG L 0.12 11.9 (    61)  UCG S 0.16  8.0 (    41)  UAG * 0.00  0.0 (     0)  UGG W 1.00 10.7 (    55)

CUU L 0.12 11.9 (    61)  CCU P 0.17  8.4 (    43)  CAU H 0.55 15.8 (    81)  CGU R 0.36 21.1 (   108)
CUC L 0.10 10.5 (    54)  CCC P 0.13  6.4 (    33)  CAC H 0.45 13.1 (    67)  CGC R 0.44 26.0 (   133)
CUA L 0.05  5.3 (    27)  CCA P 0.14  6.6 (    34)  CAA Q 0.30 12.1 (    62)  CGA R 0.07  4.3 (    22)
CUG L 0.46 46.9 (   240)  CCG P 0.55 26.7 (   137)  CAG Q 0.70 27.7 (   142)  CGG R 0.07  4.1 (    21)

AUU I 0.58 30.5 (   156)  ACU T 0.16  8.0 (    41)  AAU N 0.47 21.9 (   112)  AGU S 0.14  7.2 (    37)
AUC I 0.35 18.2 (    93)  ACC T 0.47 22.8 (   117)  AAC N 0.53 24.4 (   125)  AGC S 0.33 16.6 (    85)
AUA I 0.07  3.7 (    19)  ACA T 0.13  6.4 (    33)  AAA K 0.73 33.2 (   170)  AGA R 0.02  1.4 (     7)
AUG M 1.00 24.8 (   127)  ACG T 0.24 11.5 (    59)  AAG K 0.27 12.1 (    62)  AGG R 0.03  1.6 (     8)

GUU V 0.25 16.8 (    86)  GCU A 0.11 10.7 (    55)  GAU D 0.65 37.9 (   194)  GGU G 0.29 21.3 (   109)
GUC V 0.18 11.7 (    60)  GCC A 0.31 31.6 (   162)  GAC D 0.35 20.5 (   105)  GGC G 0.46 33.4 (   171)
GUA V 0.17 11.5 (    59)  GCA A 0.21 21.1 (   108)  GAA E 0.70 43.7 (   224)  GGA G 0.13  9.2 (    47)
GUG V 0.40 26.4 (   135)  GCG A 0.38 38.5 (   197)  GAG E 0.30 18.4 (    94)  GGG G 0.12  8.6 (    44)
/;

my $matrix_parsed = parse_kazusa_matrix(\$matrix);

print return_gff3("VORNE", translate_aa_2_nucl("AG", $matrix_parsed), "HINTEN", "NAME");

sub parse_kazusa_matrix {
    my ($ref_matrix) = (@_);
    unless (defined $ref_matrix)
    {
	$ref_matrix = \$matrix;
    }

    my $translation = {};

    while ($$ref_matrix =~ /([UTCAG]{3})\s+(.)\s+([0-9.]+)\s+([0-9.]+)\s+[(]\s+(\d+)[)]/g)
    {
	my $entry = { triplet => $1, aa => $2, fraction => $3*1, num => $4*1, counts => $5+0 };

	push(@{$translation->{$entry->{aa}}{entries}}, $entry);
	# sort (not efficient, but possible here)
	@{$translation->{$entry->{aa}}{entries}} = sort {$b->{counts} <=> $a->{counts}} (@{$translation->{$entry->{aa}}{entries}});
	$translation->{$entry->{aa}}{counts} += $entry->{counts};
    }

    return $translation;
}

sub translate_aa_2_nucl {
    my ($seq, $matrix) = @_;

    my $output_seq = "";

    foreach my $current_aa (split(//, uc($seq)))
    {
	unless (exists $matrix->{$current_aa})
	{
	    die "Missing AA $current_aa\n";
	}

	$output_seq .= $matrix->{$current_aa}{entries}[0]{triplet};
    }

    $output_seq =~ tr/Uu/Tt/;

    return $output_seq;
}

sub return_gff3 {
    my ($five_prime, $sequence_of_interest, $three_prime, $name, $file_name) = @_;

    $name =~ s/\s/_/g;

    my $seq_complete = "";

    my $gff  = "##gff-version 3\n";

    foreach my $entry (
	{seq => $five_prime, type => "five_prime_coding_exon_noncoding_region", id_extention => "five_prime_addition"},
	{seq => $sequence_of_interest, type => "insertion",  id_extention => ""},
	{seq => $three_prime, type => "three_prime_coding_exon_noncoding_region",  id_extention => "three_prime_addition"}
	)
    {
	my $id = $name;
	if( exists $entry->{id_extention} && "" ne $entry->{id_extention})
	{
	    $id .= ".".$entry->{id_extention};
	}
	$gff          .= join("\t",
			      $name,
			      "fftool",
			      $entry->{type},
			      length($seq_complete)+1,
			      length($seq_complete)+length($entry->{seq}),
			      ".",
			      "+",
			      ".",
			      "ID=".$id
	    )."\n";
	$seq_complete .= $entry->{seq};
    }

    $gff .= "##FASTA\n";
    $gff .= ">$name\n$seq_complete\n";

    return $gff;
}

1;
