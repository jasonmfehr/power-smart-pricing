#!/usr/bin/perl -w
use strict;
use warnings;
use Time::HiRes qw(usleep);
use Time::Local qw(timelocal);
use Getopt::Std qw(getopts);
$|++;

### BEGIN MAIN ###
{
my $SEC_IN_DAY = 86400;
my $SEC_IN_YEAR = 31557600;

my $poll_delay = 50000;
my $current_time;
my $end_time;
my @time_arr;
my @data;
my $poll_dt;
my $tmpdata;
my $nextidx;
my $current_date;
my %opts;

#process command line inputs
getopts("s:e:w:h?", \%opts);

if($opts{"h"} || $opts{"?"}){
  printHelp();
  exit 1;
}

if($opts{"s"}){
  $current_time = parseDate($opts{"s"});
  if(!defined($current_time)){
    print STDERR "Invalid format for start date\n";
    printHelp();
    exit 1;
  }
}else{
  $current_time = time() - $SEC_IN_YEAR * 2;
}

if($opts{"e"}){
  $end_time = parseDate($opts{"e"});
  if(!defined($end_time)){
    print STDERR "Invalid format for end date\n";
    printHelp();
    exit 1;
  }
}else{
  $end_time = time();
}

if($opts{"w"}){
  if($opts{"w"} !~ /^(\d+)$/){
    print STDERR "wait time must be numeric\n";
    printHelp();
    exit 1;
  }else{
    $poll_delay = $opts{"w"} * 1000;
  }
}
  
#open the data file where the data will be written and print out the header row
open("F", ">data.csv") or die "Cannot open file data.csv for writing";
for(my $i=0; $i<24; $i++){
 print F ",$i";
}
print F "\n"; 

#retrieve all the data
while($current_time < $end_time){
  @time_arr = localtime($current_time);
  $current_date = ($time_arr[5] + 1900) . "-" . ($time_arr[4] + 1) . "-" . $time_arr[3];
  print "Getting Data for $current_date\n";
  print F "$current_date,";

  $tmpdata = buildEmptyArr();

  $poll_dt = ($time_arr[4] + 1) . "%2F" . $time_arr[3] . "%2F" . ($time_arr[5] + 1900);
  @data = `curl -XGET -s 'http://www.powersmartpricing.org/chart/?price_dt=$poll_dt&display=table'`;

  $nextidx = 0;
  foreach(@data){
    chomp;

    if(/\<div class="error"\>No data is available/){
      print "ERROR: could not find data for $current_date\n";
      last;
    }elsif(/\<td\>(\d+(a|p)m)/){
      $nextidx = timeToIndex($1);
    }elsif(/\<td class="price"\>(\d+\.?\d*)/){
      $tmpdata->[$nextidx] = $1;
    }
  }

  print F join(",", @$tmpdata) . "\n";

  $current_time += $SEC_IN_DAY;
  usleep($poll_delay);
}

close(F);
}
### END MAIN ###



sub buildEmptyArr {
  my $newarr = [];

  for(my $i=0; $i<24; $i++){
    $newarr->[$i] = 0;
  }

  return $newarr;
}

sub timeToIndex {
  my $t = shift();
  my $idx;

  $t =~ /^(\d+)(am|pm)/;

  if($1 == 12){
    $idx = 0;
  }else{
    $idx = $1;
  }

  $idx += ($2 eq "am" ? 0 : 12);

  return $idx;
}

sub parseDate {
  my $dt = shift();

  if($dt !~ /^(\d{4})-(\d{2})-(\d{2})$/){
    return undef;
  }else{
    return timelocal(0, 0, 12, $3, $2-1, $1); 
  }
}

sub printHelp {
  print STDERR "\nUSAGE: perl $0 [-s start_date] [-e end_date] [-w delay]\n";
  print STDERR "\t -s start_date  Date in the format yyyy-mm-dd to start gathering data, default is two years before current date\n";
  print STDERR "\t -e end_date    Date in the format yyyy-mm-dd to stop gathering data, default is current date\n";
  print STDERR "\t -w delay       Amount of time in milliseconds to wait between each call to get data\n";
  print STDERR "\t                from the server.  Default is 50 milliseconds\n\n";
}
