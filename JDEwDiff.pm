package JDEwDiff;
require Exporter;

use strict;
use warnings;
use Algorithm::Diff 'traverse_sequences';
use Text::Tabs;
use IAD::XL;
use IAD::MiscFunc;

our (@ISA, @EXPORT);
@ISA = qw(Exporter);
@EXPORT= qw(diff);

#=================
# Global Variables
#=================

#================
# Local Variables
#================
my $before_file; #hold pre/before file
my $after_file;  #hold post/after file
my @a;           #hold contents of snap1 file
my @b;           #hold contents of snap2 file
my $onlya = "onlyA";
my $onlyb = "onlyB";
my $type;        #hold type of log file being processed (accounts, policies, dormant, groups, or vpn)
my %diff;        #hash to hold diffs
my $xl_filename; #file to save end results to

#========
# Diff Me
#========
sub diff_me
{
  my($before_file,$after_file,$date_str,$filename) = @_;
  $xl_filename = $filename;
  
  #read files into arrays
  open S1, $before_file or die "Can't open the $before_file file: $!\n";
  open S2, $after_file  or die "Can't open the $after_file file: $!\n";

  @a = <S1>;
  @b = <S2>;
  @a = sort @a;
  @b = sort @b;
  close S1;
  close S2;

  #chomp chomp
  preprocess(\@a);
  preprocess(\@b);

  #compare the arrays, store results in a %chgXxx hash
  traverse_sequences
  (
	\@a,    # first sequence
	\@b,    # second sequence
	{
	    MATCH     => \&match,     # callback on identical lines
	    DISCARD_A => \&only_a,    # callback on A-only
	    DISCARD_B => \&only_b,    # callback on B-only
	}
  );
  
  #=========
  # callbacks
  #=========
  sub preprocess
  {
    #chomp chomp
	  my $arrayRef = shift;
	  chomp(@$arrayRef);
	  @$arrayRef = expand(@$arrayRef);
  }

  sub match
  {
    #do nothing with matches
  }

  sub only_a
  {
    #line in snap1 that isn't in snap2
    my ($s1,$s2) = @_;

    #analyze...parse...store
    my($loc,$grp,$u,$job,$sec_details) = split/\|/, $a[$s1];
	$diff{$loc}->{$grp}->{$u}->{$job}->{$onlya}->{sec_details} = $sec_details;
  }

  sub only_b
  {
    #line in snap2 that isn't in snap1
    my ($s1,$s2) = @_;

    #analyze...parse...store
	my($loc,$grp,$u,$job,$sec_details) = split/\|/, $b[$s2];
	$diff{$loc}->{$grp}->{$u}->{$job}->{$onlyb}->{sec_details} = $sec_details;
  }

  #=======
  # Output 
  #=======
  IAD::XL::init_xl("JDE Diff");
  IAD::XL::add_header("JDE Access Changes [$date_str]","Location","Group","UserID","Job","Previous","Current","Type");
  my $before  = 0;
  my $after   = 0;
  my $change_type;
  my $b_sec_details = "";
  my $a_sec_details = "";
  
  for my $loc ( sort keys %diff )
  {
	for my $grp ( sort keys %{ $diff{$loc} } )
	{
		for my $u ( sort keys %{ $diff{$loc}->{$grp} } )
		{
			for my $job ( sort keys %{ $diff{$loc}->{$grp}->{$u} } )
			{
				for my $cb ( sort keys %{ $diff{$loc}->{$grp}->{$u}->{$job} } )
				{
					if ($cb eq $onlya)
					{
						$before = 1;
						$b_sec_details = $diff{$loc}->{$grp}->{$u}->{$job}->{$cb}->{sec_details};        
					}

					if ($cb eq $onlyb)
					{
						$after  = 1;
						$a_sec_details = $diff{$loc}->{$grp}->{$u}->{$job}->{$cb}->{sec_details};        
					}
				} #end cb for()

				#determine change type
				if ($before && $after)
				{
					$change_type = "Change";
				}
				elsif ($before && ! $after)
				{
					$change_type = "Removal";
				}
				elsif (! $before && $after)
				{
					$change_type = "Addition";
				}

				#convert sec details to strings to be written
				$b_sec_details =~ s/;/\n/g;
				$a_sec_details =~ s/;/\n/g;

				#write row
				IAD::XL::write_row($loc,$grp,$u,$job,$b_sec_details,$a_sec_details,$change_type);

				#release memory
				$before = 0;
				$after  = 0;    
				$change_type  = "";
    
				#temps
				$b_sec_details = "";
				$a_sec_details = "";
			} #job for()
		} #u for()
	} #grp for()
  } #loc for()

  
  #=========
  # Finish Up
  #=========
  IAD::XL::end_formatting;
  IAD::XL::exit_xl($xl_filename);
  print "\n";
  print "Saved diff file to: $xl_filename\n\n";

} #end diff()

#=============
# Return value
#=============
return 1;