#!/usr/bin/perl

my %Projects;
my %Images;

open CMD, "gcloud compute images list |";
while(<CMD>) {

	chomp;
	my @a = split ' ';

	my $family = $a[2];
	my $image = $a[0];
	my $project = $a[1];

	$Projects{$family} = $project;
	$Images{$family} = $image;

}

foreach my $i (@ARGV) {
	print "projects/$Projects{$i}/global/images/$Images{$i}";
}
