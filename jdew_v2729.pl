#========================
#JDE Security Audit Program
#=========================
use strict;
use warnings;
use Graph;
use Mnode;
use JDEwData_v2729;
use JDEwConf;
use JDEwDiff;
use Getopt::Long;
use Storable;
use Win32::OLE qw(in valof with);
use Win32::OLE::Const 'Microsoft Excel';
use Win32::Service;

#export global variables
our (@ISA, @EXPORT);
@ISA = qw(Exporter);
@EXPORT= qw($offline_dir $id $pwd $dsn $cwd $ts $before_dir $after_dir);

#====
#Vars
#====
my  %opts;
my  %lvl;          #use to hold any mtoe's
my  %rpt;          #hold info to be used for final report
my  %job;          #hold jobs by location/group for assigning worksheet rows
my  %status;       #used in checkpoint functions
my  $levels_deep;  #number of levels to recurse to when building menu trees
my  $v;            #use to hold verticies
our $id;		   #user id to log onto AS400
our $pwd;		   #password to log onto AS400
our $dsn;		   #ODBC data source 
our $offline_dir;  #offline flag - checked by JDEwData.pm module to see if online or offline processing should take place
my  $run;          #hold run type for script
our $before_dir;   #before directory for diff run
our $after_dir;    #after directory for diff run
my  $name;         #more friendly name for jdesec and slsec DSNs
our $cwd = IAD::MiscFunc::get_cwd();       #current working dir
$cwd = "$cwd\\.."; #kludge for adding a 'code' dir to better organize things
our $ts  = IAD::MiscFunc::get_timestamp(); #time stamp
my  $xl;		   #xl instance
my  $bk;           #workbook instance
my  $sh;           #worksheet instance
my @xlcol = ("A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P",
             "Q","R","S","T","U","V","W","X","Y","Z","AA","AB","AC","AD","AE",
             "AF","AG","AH","AI","AJ","AK","AL","AM","AN","AO","AP","AQ",
             "AR","AS","AT","AU","AV","AW","AX","AY","AZ");

#===================
#Process Command Line
#===================
my $cl_result = GetOptions (\%opts,'dsn=s','u=s','p=s','run=s','kill-chkpt','h','offline-dir=s','before-dir=s','after-dir=s');

#print usage if no parameters passed
my @keys = keys %opts;
unless (@keys)
{
  #usage();
}

#print usage if -h (help) parameter is passed
if ($opts{'h'})
{
  #usage();
}

unless ( $opts{'run'} )
{
	print "\n\n";
	print "Must pass the 'run' parameter to tell me what report to produce.\n";
	#usage();
}

if ( lc( $opts{'run'} ) eq "report" ) 
{
	unless ($opts{'dsn'} && $opts{'u'} && $opts{'p'} && $opts{'run'})
	{
		print "\n\n";
		print "For a 'report' run, must pass the following options: dsn, u, p and run.\n";
		#usage();
	}
}

if ( lc( $opts{'run'} ) eq "diff" )
{
	unless ($opts{'before-dir'} && $opts{'after-dir'})
	{
		print "\n\n";
		print "For a 'diff' run, must pass the following options: before-dir and after-dir.\n";
		#usage();
	}
}
#store parameters
$id          = $opts{'u'};
$pwd         = $opts{'p'};
$dsn         = $opts{'dsn'};
$run         = $opts{'run'};
$offline_dir = $opts{'offline-dir'};
$before_dir  = $opts{'before-dir'};
$after_dir   = $opts{'after-dir'};

#get a more friendly name
unless ($dsn) { $dsn = "NONE"; }
if ($dsn eq "jdesec")
{
	$name = "hq";
}
elsif ($dsn eq "slsec")
{
	$name = "smwe";
}
else
{
	$name = $dsn;
}

#ascii art
unless ( lc($dsn) eq "slsec" )
{
print "\n\n";
print 
"


	 ______________
	|//////////////|
        |//////////////|
        |//////////////|
           |.......|
           |.......|
           |.......|
           |.......||\\  |-()()()
	   |.......|| \\ | 
      ||||||.......||{}\\|-000000
       |...........||  /|
       |___________||_/ |-()()()
           --        --
           \\ \\      / /|[] |  |\\
            \\ \\    / / |\\  |  |o\\
             \\ \\/\\/ /  | \\ |  | /
             {------}[]|  \\|[]|/ 
";
print "\n\n";
}
else
{
print "\n\n";
print 
"


     
 	                    &&&&&&     |>>>>>
                          |\\\\\\|        |
                          |///|        |
                          |\\\\\\|        |
                          |///|        |
                          |\\\\\\|        |
                          |///|        |>>>>>
                          |\\\\\\|        |
                          |///|        |
			  |\\\\\\|        |
 			  |///|        |
		       &&&&&&  |\\/|{/\\}|>>>>>
	
		0000000000
		0000000000
		0000000000	
		   0000  +++++        +++++               
		   0000  +++++        +++++
                   0000   ++++        ++++
                   0000    +++        +++
		0000000	   +++   /\\   +++
		000000      ++  /  \\  ++
		00000|}E     ==/    \\==01101111011100100110110001100100

";
print "\n\n";
}
	
#call main function
if ( $opts{'kill-chkpt'} ) { kill_checkpoint(); }

if ( lc($run) eq "report")
{
	main_report();
}
elsif ( lc($run) eq "diff")
{
	main_diff();
}

if ( $opts{'kill-chkpt'} ) { restart_checkpoint(); }

#==============
# main_report()
#==============
sub main_report
{
	#ADD IN CONFIGURATION FILE PARSING ROUTINE TO ENSURE CERTAIN VALUES ARE DEFINED - LIKE "LD"
	
	#get configuration information
	JDEwConf::get_conf();	
	if ( lc($dsn) eq "jdesec") { JDEwConf::update_location_info(); }
	$levels_deep = $JDEwConf::conf{$dsn}->{LD};
	
    #create jde info obj
    my $jde = JDEwData->spawn($id,$pwd,$dsn);

    #open db connection
    $jde->open_db();
	
	#create directories
	$jde->create_dirs();
		
    #get menu selections data for all menus, adv menus, setup menus
    my ($ms,$as,$ss) = $jde->get_menu_selections;
	
	#get ids, init menu, composite keys, mt, cmd, fp
	my $id = $jde->get_user_data;
	
	#get overall locks and adv/set menus mappings
	my ($ol,$am,$sm) = $jde->get_overall_locks;

	#get security details - these calls are dependent on the calls made above, so don't move around
	my($hs) = $jde->get_hs;   #get zhidden selections
	my($fk) = $jde->get_fk;  #get function key security details
	my($ac) = $jde->get_ac;  #get action code security details and search type security details if we're processing 'jdesec'	
	my($pd) = $jde->get_pd;  #get program descriptions details
	my($ui) = $jde->get_ui;  #get audusrprf info - mainly just to get name associated with id
	
	#close db connection
	$jde->close_db;
		
	#create menu tree for each user
	for my $u (sort keys %{ $id })
	{
		#get location
		my $loc;
		if ($dsn eq "slsec" )    { $loc = "SMWE"; }
		elsif ($dsn eq "jdesec") { $loc = $JDEwConf::hq_loc{$u}->{loc}; }
		else                     { $loc = $dsn; }
		unless ($loc) { $loc = "No_Location"; }
		
		#get group
		my $grp = $id->{$u}->{gp};
		unless ($grp) { $grp = "No_Group"; }
		$grp =~ s/^\*//;
		print "Building menu tree for $u " . " " x (7 - length($u)) . "[$loc:$grp]...\n";
		
		#create tree
	    my $t = Graph->new('refvertexed' => 1); #allow references as verticies

	    #create root of tree - root node is always init menu, selection 0
	    #this is just a placeholder to have a root of the tree, nothing else
	    my $r = $id->{$u}->{init};
	    my $root = Mnode->spawn($r,0,undef,undef,undef,undef,undef,undef,undef);

	    #create root of tree
	    $t->add_vertex($root);

	    #level 1 - get all children of user's initial menu
	    for my $sel (keys %{ $ms->{$r} })
	    {
			my $a = $ms->{$r}->{$sel}->{a};
	 	    my $d = $ms->{$r}->{$sel}->{d};
	 	    my $j = $ms->{$r}->{$sel}->{j};
	 	    my $k = $ms->{$r}->{$sel}->{k};
	 	    my $f = $ms->{$r}->{$sel}->{f};
	 	    my $jexc = $ms->{$r}->{$sel}->{jexc};
	 	    my $jver = $ms->{$r}->{$sel}->{jver};
	 	    my $mexc = $ms->{$r}->{$sel}->{mexc};
			my $batv = $ms->{$r}->{$sel}->{batv};
			my $adv =  $am->{$r}->{adv};
			my $set =  $sm->{$r}->{set};

	 	    if (
	           $jde->locks($r,$id->{$u}->{a},$id->{$u}->{d},$id->{$u}->{j},
	 	                   $id->{$u}->{k},$id->{$u}->{f},$a,$d,$j,$k,$f)
	 	       )
	 	    {
	 	 	    #passed locks - user can get there
				$v = Mnode->spawn($r,$sel,$jexc,$jver,$mexc,$root,$adv,$set,$batv);
				
				#add edge from parent vertex to child
	    	    $t->add_edge($root,$v);	
	 	    }
			else
			{
			    next;
			}

			#if mexc exists, note it to be processed at next level
	 	    if ($mexc)
			{
				$lvl{1}->{$mexc}->{pv} = $v;
			}
			
			#if user has the ability to do a 27, check to see if there is an adv menu defined - if yes, add it to be processed				
			if ($hs->{$u}->{27} && $adv)
			{
				#instantiate a menu node to represent the 27 jump
				my $v_adv = Mnode->spawn($r,27,$jexc,$jver,$mexc,$v,$adv,$set,$batv);
				
				#add edge from parent vertex to child
				$t->add_edge($v,$v_adv);	
					
				#add to next level to be processed 
				$lvl{1}->{$adv}->{pv} = $v_adv;
			}
				
			#if user has the ability to do a 29, check to see if there is a set menu defined - if yes, add it to be processed				
			if ($hs->{$u}->{29} && $set)
			{
				#instantiate a menu node to represent the 29 jump
				my $v_set = Mnode->spawn($r,29,$jexc,$jver,$mexc,$v,$adv,$set,$batv);
					
				#add edge from parent vertex to child
				$t->add_edge($v,$v_set);	
					
				#add to next level to be processed 
				$lvl{1}->{$set}->{pv} = $v_set;
			}			
		}

	    #do levels 2 thru whatever levels_deep is set at
	    for my $clv ( 2 .. $levels_deep )
	    {
	      for my $menu (keys %{ $lvl{($clv-1)} })
	      {
			my $pv = $lvl{($clv-1)}->{$menu}->{pv};
					
	 	    for my $sel (keys %{ $ms->{$menu} })
	 	    {
	 	        my $a = $ms->{$menu}->{$sel}->{a};
	 	        my $d = $ms->{$menu}->{$sel}->{d};
	 	        my $j = $ms->{$menu}->{$sel}->{j};
	 	        my $k = $ms->{$menu}->{$sel}->{k};
	 	        my $f = $ms->{$menu}->{$sel}->{f};
	 	        my $jexc = $ms->{$menu}->{$sel}->{jexc};
	 	        my $jver = $ms->{$menu}->{$sel}->{jver};
	 	        my $mexc = $ms->{$menu}->{$sel}->{mexc};
				my $batv = $ms->{$menu}->{$sel}->{batv};
				my $adv = $am->{$menu}->{adv};
				my $set = $sm->{$menu}->{set};
					
	 	        #locks test
	 	        if (
	                $jde->locks($menu,$id->{$u}->{a},$id->{$u}->{d},$id->{$u}->{j},
	 	                        $id->{$u}->{k},$id->{$u}->{f},$a,$d,$j,$k,$f)
	 	            )
	 	        {					
					#passed					
					$v = Mnode->spawn($menu,$sel,$jexc,$jver,$mexc,$pv,$adv,$set,$batv);

					#add edge from parent vertex to child
					$t->add_edge($pv,$v);	
				}
				else
	 	        {						
	 	   	      next;
	 	        }

	 	        #if mexc exists, note it to be processed at next level
	 	        if ($mexc)
				{						
					$lvl{$clv}->{$mexc}->{pv} = $v; 
				}
				
				#if user has the ability to do a 27, check to see if there is an adv menu defined - if yes, add it to be processed				
				if ($hs->{$u}->{27} && $adv)
				{
					#instantiate a menu node to represent the 27 jump
					my $v_adv = Mnode->spawn($menu,27,$jexc,$jver,$mexc,$v,$adv,$set,$batv);
					
					#add edge from parent vertex to child
					$t->add_edge($v,$v_adv);	
					
					#add to next level to be processed 
					$lvl{$clv}->{$adv}->{pv} = $v_adv;
				}
				
				#if user has the ability to do a 29, check to see if there is a set menu defined - if yes, add it to be processed				
				if ($hs->{$u}->{29} && $set)
				{
					#instantiate a menu node to represent the 29 jump
					my $v_set = Mnode->spawn($menu,29,$jexc,$jver,$mexc,$v,$adv,$set,$batv);
					
					#add edge from parent vertex to child
					$t->add_edge($v,$v_set);	
					
					#add to next level to be processed 
					$lvl{$clv}->{$set}->{pv} = $v_set;
				}
			}
          }
		}

	    #clear levels memory
	    %lvl = ();

	    #store data
	    $u =~ s/^\*//; #damn *GL user - wtf
		
	    #$jde->st0r3M3(\$t,\$u);
		
		#loop over all verticies and determine all critical jobs the user can get to
		my @v = $t->vertices();
		
		for my $v ( @v )
		{
			my $job = $v->get_jexc();
			my $ver = $v->get_jver();
			unless ($job) { next; }
			
			#is it critical?
			if ( $JDEwConf::conf{$dsn}->{CP}->{$job} )
			{
				#a critical program - store at location/group/user/job/version level for report
				my $jver = $v->get_jver();
				$rpt{$loc}->{$grp}->{$u}->{$job}->{$jver}->{type} = $JDEwConf::conf{$dsn}->{CP}->{$job};
				$rpt{$loc}->{$grp}->{$u}->{$job}->{$jver}->{batv} = $v->get_batv();
				
				#keep track of jobs by location/group
				$job{$loc}->{$grp}->{$job}->{type} = $JDEwConf::conf{$dsn}->{CP}->{$job};
				
				#print path to job
				open PATH, ">>$JDEwData::mtd\\$u.csv"
					or die "Can't open $u menu path file: $!\n";
				print PATH "$job|$ver|";
				my @path = ();
				my $pv;
				push @path,  $v->get_menu . ":" . $v->get_sel();
						
				$pv = $v->get_parent_vertex();
				while ( ( lc( $pv->get_menu() ) ne lc( $root->get_menu() ) ) && ( int( $pv->get_sel() ) ne int( $root->get_sel() ) ) )
				{		
					#haven't recursed to root yet, so store and iterate
					push @path, $pv->get_menu . ":" . $pv->get_sel();
					$pv = $pv->get_parent_vertex();							
				}						
				push @path, $root->get_menu() . ":" . $root->get_sel();	
				
				#print path				
				@path = reverse @path;
				foreach my $p ( @path )
				{
					print PATH "$p" . " ";
				}
				print PATH "\n";				
			}
		}
	} #end user loop

	#output	
	print "\n";
	print "Writing XL files...\n";
	
	open LOG, ">$JDEwData::logd\\jdew.$name.$ts.txt"
		or die "Can't open the log file ($JDEwData::logd\\jdew.$name.$ts.txt): $!\n";
		
	for my $loc ( sort keys %rpt )
	{
		#create a workbook for this location
		$xl = Win32::OLE->new('Excel.Application', 'Quit') or die "Can't create a new XL instance: " . Win32::LastError();
		$xl->{DisplayAlerts}=0;
		$xl->{SheetsInNewWorkbook}=0;
		$bk = $xl->Workbooks->Add or die "Can't add a new workbook to xl instance: " . Win32::LastError();
		my $filename = "$JDEwData::outd\\$loc.xls";
						
		for my $grp ( sort keys %{ $rpt{$loc} } )
		{
			#add a worksheet for this group
			$sh = $bk->Worksheets->Add({After=>$bk->Worksheets($bk->Worksheets->{Count})}) 
						or die "Can't add worksheet: " . Win32::OLE->LastError();
			$sh->{Name} = $grp;
			
			#sheet header
			$sh->Range("A1")->{Value} = "JD Edwards Access Report";
			$sh->Range("A2")->{Value} = "Time Stamp: $ts";
			$sh->Range("A3")->{Value} = "Location: $loc";
			$sh->Range("A4")->{Value} = "Group: $grp";
			
			#assign each user a column
			my %id_col = ();
			my @u = keys %{ $rpt{$loc}->{$grp} };
			@u = sort @u;
							
			my $i = 1; #start at column B
			for my $u ( @u )
			{
				$id_col{$u} = $xlcol[$i];
				$i++;
			}
			
			#assign each job for this group a row
			my %job_row = ();
			my @j = keys %{ $job{$loc}->{$grp} };
			@j = sort @j;
			
			$i = 8;  #start at row 8 in each worksheet to allow for some header details
			for my $j ( @j )
			{
				$job_row{$j} = $i;
				$i++;
			}
						
			for my $u ( sort keys %{ $rpt{$loc}->{$grp} } )
			{			
				for my $job ( sort keys %{ $rpt{$loc}->{$grp}->{$u} } )
				{
					my $col  = $id_col{$u};
					my $row  = $job_row{$job};
					my $type = $job{$loc}->{$grp}->{$job}->{type};
					my $str = "";  #cell string for security details
					
					#row 6 is the id row in matrix, and column A is the job column in matrix
					$sh->Range($col . 5)->{Value}   = $u;
					$sh->Range($col . 6)->{Value}   = $ui->{$u}->{name};
					$sh->Range("A" . $row)->{Value} = $job . " " x (10 - length($job) ) . ":: " . $pd->{$job}->{desc};
					
					#get security details for this job
					if ( lc( $type ) eq "ac" )
					{
						my $add = $ac->{$u}->{$job}->{add};
						my $chg = $ac->{$u}->{$job}->{change};
						my $dlt = $ac->{$u}->{$job}->{delete};
						
						#by default if no details exist, the user is given access
						unless ($add) { $add = "Y"; } 
						unless ($chg) { $chg = "Y"; } 
						unless ($dlt) { $dlt = "Y"; }
						$str = "A = $add :: C = $chg :: D = $dlt";
						
						#write 
						$sh->Range($col . $row)->{Value} = $str;					
					}
					elsif ( lc( $type ) eq "fk" )
					{
						my @fks = keys %{ $fk->{$u}->{$job} };
						my $cnt = scalar @fks;
						
						if ($cnt)
						{
							for my $fkey ( sort keys %{ $fk->{$u}->{$job} } )
							{
								my $desc  = $fk->{$u}->{$job}->{$fkey}->{desc};
								my $allow = $fk->{$u}->{$job}->{$fkey}->{allow};
							
								$str .= "$fkey :: $desc :: $allow\n";						
							}
						}
						else
						{
							#no fkeys defined, user has default access to all function keys
							$str .= "No funcion keys secured!\n";
							$str .= "Access to ALL function/option\n";
							$str .=	"keys by default!";
						}
						
						#write 
						$sh->Range($col . $row)->{Value} = $str;										
					}
					elsif ( lc( $type ) eq "st" )
					{
						for my $dt ( sort keys %{ $ac->{$u}->{$job}->{ST} } )
						{
							my $add  = $ac->{$u}->{$job}->{ST}->{$dt}->{add};
							my $chg  = $ac->{$u}->{$job}->{ST}->{$dt}->{change};
							my $dlt  = $ac->{$u}->{$job}->{ST}->{$dt}->{delete};
							my $desc = $ac->{$u}->{$job}->{ST}->{$dt}->{desc};
							
							#by default if no details exist, the user is NOT given access to this doc type
							unless ($add) { $add = "N"; } 
							unless ($chg) { $chg = "N"; } 
							unless ($dlt) { $dlt = "N"; }
							$str = "$dt :: $desc :: A = $add . C = $chg . D = $dlt";
							
							#write 
							$sh->Range($col . $row)->{Value} = $str;										
						}
					}
					else
					{
						$str = "Unknown Type ($type)";
						
						#write 
						$sh->Range($col . $row)->{Value} = $str;
					}
					
					#log for diff report runs
					$str =~ s/\n/;/g;
					print LOG "$loc|$grp|$u|$job|$str\n";
					
				}
			}
		}
		
		#delete initial sheet and end formatting
		$bk->Worksheets("Sheet1")->Delete;
		for my $fit_sh (in $bk->{Worksheets})
		{
			$fit_sh->Range("A1:AZ65536")->{VerticalAlignment} = xlTop;
			$fit_sh->Range("A1:AZ65536")->{HorizontalAlignment} = xlLeft;
			$fit_sh->Range("A5:AZ5")->{HorizontalAlignment} = xlCenter;
			$fit_sh->Range("A5:AZ5")->Font->{Bold} = 1;
			$fit_sh->Range("A6:AZ6")->{HorizontalAlignment} = xlCenter;
			$fit_sh->Range("A6:AZ6")->Font->{Bold} = 1;
			$fit_sh->Range("A1:A65536")->Font->{Bold} = 1;
			$fit_sh->Range("A6:AZ6")->Font->{Underline} = xlUnderlineStyleSingle;
			$fit_sh->Columns("A:AZ")->{ColumnWidth} = 100.00;
			$fit_sh->Rows("7:7")->{RowHeight} = 5.00;
			$fit_sh->Columns("A:AZ")->AutoFit();
		}
    
		#save workbook
		$bk->SaveAS($filename) or die "Can't save the file as $filename: $!\n";
		$bk->Close or die "Can't close the excel workbook: $!\n";
	}
	close LOG;
} #end main_report()	

#===========
# main_diff()
#===========
sub main_diff
{
	my($jdew_b,$loc_b,$mon_b,$day_b,$yr_b,$hr_b,$min_b,$sec_b) = split/\./, $before_dir;
	my($jdew_a,$loc_a,$mon_a,$day_a,$yr_a,$hr_a,$min_a,$sec_a) = split/\./, $after_dir;
	
	unless ($loc_b eq $loc_a)
	{
		print "\n\n";
		print "It looks like you're trying to compare to different machines: $loc_b vs. $loc_a.\n";
		print "This is almost certainly inaccurate...so much so, that I'm pulling the plug right now.\n";
		print "If you're soooooo sure that these are really the same systems (or you just want to compare\n";
		print "two different systems), then rename the directories to be the same jdew.[SYSTEM].* name.\n";
		print "But this isn't the normal way the script is intended to run...hopefully you know what you're\n";
		print "doing!\n";
		print "\n\n";
		print "Hasta luego...\n";
		print "\n\n";
		exit;
	}
	
	my $before_file = "$cwd\\$before_dir\\log\\$before_dir.txt";
	my $after_file  = "$cwd\\$after_dir\\log\\$after_dir.txt";
	my $date_str    = "$mon_b/$day_b/$yr_b vs. $mon_a/$day_a/$yr_a";
	my $filename    = "$cwd\\$after_dir\\log\\" . "diff.$loc_a." . "$mon_b.$day_b.$yr_b" . "_vs_" . "$mon_a.$day_a.$yr_a" . ".xls";
	JDEwDiff::diff_me($before_file,$after_file,$date_str,$filename);

} #end main_diff()
	
	
	
	
	
#walking the tree type of logic
#my $p_str2;								
#while ( $pv->get_menu() ne $root->get_menu() && $pv->get_sel() ne $root->get_sel() )
#{		
#  $p_str2 = " -> " . $pv->get_menu() . " " . $pv->get_sel() . $p_str2;
#	$pv = $pv->get_parent_vertex();							
#}						
#$p_str2 = $root->get_menu() . " " . $root->get_sel() . $p_str2;		
	
	
#make a method for retrieval also
#retrieve stored data - to be used in analysis routines
# print $JDEwData::mtd . "\\RDP.mt" . "\n";
# my $t_r = retrieve("$JDEwData::mtd\\RDP.mt");
# my @v = $t_r->vertices;

# open JOBS, ">RDP_Jobs.csv"
	# or die "fizzle...\n";
# open MENUS, ">RDP_Menus.csv"
	# or die "dead...\n";
	
# for my $v (@v)
# {
  # print JOBS  $v->get_jexc,"|",$v->get_jver,"\n";
  # print MENUS $v->get_menu,"|",$v->get_sel,"\n";
  #my $parent = $v->get_parent_vertex;
  #while ($parent)
  #{
  #  print $parent->get_menu," ",$parent->get_sel,"\n";
  #  $parent = $parent->get_parent_vertex;
  # }
#}
#close JOBS;
#close MENUS;

#==========================
# Checkpoint Killing/Restarting
#==========================
sub kill_checkpoint
{
  Win32::Service::GetStatus('','SR_Service',\%status);
  if ($status{CurrentState} == 1)
  {
    print "'Check Point SecuRemote' service is not running...schweet!\n";
  }
  else
  {
    Win32::Service::StopService('','SR_Service') ||
       die "I can't stop the 'Check Point SecuRemote' service...do you have Administrator rights? If not, then get them (one way or the other).\n";
    print "'Check Point SecuRemote' service stopped...\n";
  }

  Win32::Service::GetStatus('','SR_WatchDog',\%status);
  if ($status{CurrentState} == 1)
  {
    print "'Check Point WatchDog' service is not running...schweet!\n";
  }
  else
  {
    Win32::Service::StopService('','SR_WatchDog') ||
       die "I can't stop the 'Check Point WatchDog' service...do you have Administrator rights? If not, then get them (one way or the other).\n";
    print "'Check Point WatchDog' service stopped...\n";
  }
}

sub restart_checkpoint
{
  Win32::Service::StartService('','SR_Service');
  Win32::Service::StartService('','SR_WatchDog');
}

#=======
#Usage()
#=======
sub usage
{
  print "\n\n";
  print "Usage:\n\n";
  print "jdew.exe [-dsn ODBC Data Source] [-u username] [-p password]","\n";
  print "         [--run [report|diff]] [--before-dir c:\\path\\to\\before_files] ","\n";
  print "         [--after-dir c:\\path\\to\\after_files] [--kill-chkpt] [-h]","\n";
  print "\n";
  print "--dsn         ODBC Data Source set up for this server. Required ","\n";
  print "              for a 'report' run.  This is the system that will be ","\n";
  print "              queried to obtain all the necessary data.","\n";
  print "\n";
  print "-u            Username to use to log into the system represented by ","\n";
  print "              the DSN parameter.","\n";
  print "\n";
  print "-p            Password to use to log into the system represented by ","\n";
  print "              the DSN parameter.","\n";
  print "\n";
  print "--run         The type of run the script should perform.","\n";
  print "              This is ALWAYS a required parameter, and is either ","\n";
  print "              'report' for a normal report run or a 'diff' for a ","\n";
  print "              diff of two previous runs.","\n";
  print "\n";
  print "--before-dir  If running a 'diff' report this is the pre/before ","\n";
  print "              directory from a previous run.  This represents the ","\n";
  print "              beginning date for the comparison.","\n";
  print "\n";
  print "--after-dir   If running a 'diff' report this is the post/after ","\n";
  print "              directory from a previous run.  This represents the ","\n";
  print "              ending date for the comparison.","\n";
  print "\n";
  print "--kill-chkpt  Specify this option to have the script kill ","\n";
  print "              the checkpoint services.  Generally this ","\n";
  print "              should not be required, but may be at SMWE.","\n";
  print "\n";
  print "-h            Print this help.","\n";
  print "\n";
  exit;

} #end usage()
