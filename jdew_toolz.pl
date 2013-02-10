#=============================================================
# IAD Toolz Menu System Program
#
# Provide a menu system to drive all IAD related programs.  Additionally 
# provide some fun ASCII art for some silliness.
#============================================================
use strict;
use warnings;
use IAD::MiscFunc;
use IAD::XL;
use Term::ReadPassword::Win32;
use Date::Calc;
use Time::Local;
use File::Basename;
use File::Glob ':glob';
use Storable;
use Graph;
use JDEwConf;

my %diff_conf;
my %post_dir;
my $cwd = IAD::MiscFunc::get_cwd(); #current working dir

system("cls");
print 
"

                                       
                                              
                                                           
                                           DN   +u,  ]00   
                                           BM   +0f  ]Qi   
                                           EM    0L  ]0M   
                                   _N0c  IR;  ]ju   
                                          0MM0c GMi ,FQ0u  
                                         400MMi](ui,i5B00n 
                          []    []      ]iNM00muuuu0uBuM  
                           [][][]       yqmm] LmpB00iuN  
                            [][]orld    |l~~~]+MM^BM800M  
                         |    ] , q]0N0MM  
                                             ]    ]   ^]Mui00                   
            _gmo_gmq_     _gM+,w .           ]gNNN4    ]M80N0                   
           gMMp00D0MM0_  4BF,~, ,- q         ]000Mu    440Qii                   
          40'pMMig0mMQ0wu08/  ,--            ]M00MHuQi0800Mu0                   
         jL9Q0EuiM00NB00 i= ,,,.,,   )       ]0i0iQQ0Nig0MM0M                   
         Khoi--------0MpLI.-------- ~ ,grmMM*ycau,   ,, _pq   _           
         Hw | SKOAL  |FiuLI| COPE |l  4K8Qdou0g8(X8Z  PMF2KT(5~D8M              
         ijH|--------|mgoul|------| uFEB--------giloMM---------08Mo,              
         4pI4iWiT8BTMM0i_0znnnqnnlp;8u0g| HUSKY |gMm,n| Rooster |;yJ              
          QMOMMNMNMuQii ]gu,l;;;;loi-^mm--------NiZ(pm----------mMi~               
           M0AZNMN0Mu4   ~0ig_l_o.   0ubV!pq!kj!Nu0 0MWiignnni34]in                
            l7M0p5llo       o~o       oiM0iT~DMp80M  A4L(pgpq_pd*'   
                                         -  ~~                  
										 
";

main();

#==========
# Main Sub()
#==========
sub main
{
	#handle a Ctrl-C scenario
    $SIG{INT} = "interrupt";

	print "\n";
	MENU_LVL_TOP:
	
	print "---------- Reports ----------","\n";
	print "1. JDE world access report.","\n";
	print "2. JDE world diff report.\n";
	print "\n\n";
	print "----------  Tools  ----------","\n";
	print "3. Find a user's path to a program.","\n";
	print "4. List directories available for a 'diff' run.","\n";
	print "5. Run a GL approval tree report.","\n";
	print "\n\n";
	print "6. I'm a quitter.","\n";
	print "\n\n";
	print "What'll it be?: ";
	chomp(my $sel = <STDIN>);
	
	unless ( $sel eq "1" || $sel eq "2" || $sel eq "3" || $sel eq "4" || $sel eq "5" || $sel eq "6" ) 
	{
		print "\n";
		print "Invalid selection...try again.","\n";
		print "\n\n";
		undef $sel;
		goto MENU_LVL_TOP;
	}
	
	#process selection
	if ( $sel eq "1" )
	{
		#========================
		# 1. JDE world access report.
		#========================
		MENU_LVL_JDEW_RPT:
		system("cls");
		print "\n\n";
		print "1. HQ","\n";
		print "2. Winery","\n";
		print "\n";
		print "Enter Selection: ";
		chomp( $sel = <STDIN> );
	
		#error check
		unless ( $sel eq "1" || $sel eq "2" ) 
	    {
			print "\n";
			print "Invalid selection...try again.","\n";
			undef $sel;
			goto MENU_LVL_JDEW_RPT;
	    }
			
		if ( $sel eq "1" )
		{			
			system("cls");
			print "\n\n";
			print ".:: Needed Parameters ::.","\n";
			print "---------------------------------","\n";
			print "Parameter           Value       ","\n";
			print "---------------------------------","\n";
			print "User ID             ";
			chomp(my $id = <STDIN>);	
			my $pass = read_password('Password            ');				
			print "\n\n";			
			system("jdew.exe --dsn jdesec -u $id -p $pass --run report");
			print "\n\n\n";
			print "Processing Complete!";
			print "\n\n";
			print "Have a day now :-)!\n";
			exit;
		}
		elsif ( $sel eq "2" )
		{
			system("cls");
		    print "\n\n";
			print ".:: Needed Parameters ::.","\n";
			print "---------------------------------","\n";
			print "Parameter           Value       ","\n";
			print "---------------------------------","\n";
			print "User ID             ";
			chomp(my $id = <STDIN>);	
			my $pass = read_password('Password            ');				
			print "\n\n";
			system("jdew.exe --dsn slsec -u $id -p $pass --run report --kill-chkpt");
			print "\n\n\n";
			print "Processing Complete!";
			print "\n\n";
			print "Have a day now :-)!\n";
			exit;
		}	
	}
	elsif ( $sel eq "2" )
	{
		#=======================
		# 2. JDE world diff report.
		#=======================
		system("cls");
		print "\n\n";
		print ".:: Needed Parameters ::.","\n";
		print "--------------------------------------------------------------------------------------------","\n";
		print "Parameter                                                      Value                        ","\n";
		print "--------------------------------------------------------------------------------------------","\n";
		print "First Snapshot Directory (e.g. jdew.hq.5.1.2008.14.28.7)      ";
		chomp(my $predir = <STDIN>);
		print "Second Snapshot Directory (e.g. jdew.hq.5.15.2008.7.23.44)      ";
		chomp(my $postdir = <STDIN>);
		print "\n\n";
		system("jdew.exe --run diff --before-dir $predir --after-dir $postdir");
		print "\n\n\n";
		print "Processing Complete!";
		print "\n\n";
		print "Have a day now :-)!\n";
		exit;
	}
	elsif ( $sel eq "3" )
	{
		#========================
		# 3. User's path to a program
		#========================
		MENU_LVL_JDEW_PATH:
		system("cls");
		print "\n\n";
		print "1. HQ","\n";
		print "2. Winery","\n";
		print "\n";
		print "Enter Selection: ";
		chomp( $sel = <STDIN> );
	
		#error check
		unless ( $sel eq "1" || $sel eq "2" ) 
	    {
			print "\n";
			print "Invalid selection...try again.","\n";
			undef $sel;
			goto MENU_LVL_JDEW_PATH;
	    }
		
		if ( $sel eq "1" )
		{			
			system("cls");
			print "\n\n";
			print ".:: Needed Parameters ::.","\n";
			print "---------------------------------","\n";
			print "Parameter           Value       ","\n";
			print "---------------------------------","\n";
			print "User ID             ";
			chomp(my $id = <STDIN>);	
			print "Program             ";
			chomp(my $prog = <STDIN>);
			print "\n\n";
			print "++++++++++ Paths Found ++++++++++\n";
			
			#get latest run directory to search in
			$id = IAD::MiscFunc::trim($id);
			$prog = IAD::MiscFunc::trim($prog);
			$prog =~ s/^P/J/;
			
			#get latest directory
			my @jdew_hq = bsd_glob ("$cwd\\..\\jdew.hq.*");
			my($lmon,$lday,$lyr,$lhr,$lmin,$lsec) = (1,1,1,0,0,0); #latest time
			my $latest;
			for my $dir (@jdew_hq)
			{
				my($per1,$per2,$jdew,$loc,$mon,$day,$yr,$hr,$min,$sec) = split /\./, $dir;
				my($dir_name,$dir_path,$dir_suffix) = fileparse($dir,qr()) or die "Can't parse $dir\n";
			
				#make amends for adding 1 in IAD::MiscFunc::get_timestamp()
				$mon -= 1;
	
				my $time1 = timelocal($lsec,$lmin,$lhr,$lday,$lmon,$lyr);
				my $time2 = timelocal($sec,$min,$hr,$day,$mon,$yr);
				my $diff  = $time1 - $time2;
	
				if ( $diff < 0 )
				{
					#currently stored latest is earlier than currently procesed date, change latest to current
					$latest = $dir_name;
					($lmon,$lday,$lyr,$lhr,$lmin,$lsec) = ($mon,$day,$yr,$hr,$min,$sec);		
				}
			}		
			unless ($latest) { print "No Directories Found!\n\n"; exit;}
			
			#get menu tree file for the user ID specified
			my $file = "$cwd\\..\\$latest\\menu_trees\\$id.csv";
			if (-e $file) 
			{
				#open file and search for job
				open MT, "$file"
					or die "Can't open the user's menu tree file ($file): $!\n";
				my $i = 1;
				while (<MT>)
				{
					chomp;					
					my($job,$ver,$path) = split/\|/;
					if ( lc($prog) eq lc($job) )
					{
						print "Path $i:\n";
						print "\tVersion: $ver\n\n";
						my @path = split/\s+/, $path;
						for my $p ( @path )
						{
							print "\t$p\n";						
						}
					    print "\n";
						$i++;
					}
				}				
				close MT;				
			}
			else
			{
				print "User ID :: $id\n";
				print "Can't locate this profile's file ($file)\n";
				print "in the latest directory($latest).\n";
				print "\n";
				print "Are you sure this profile is *ENABLED and has access to production data?\n";
				print "Either way...this profile does not have a menu tree for the latest run.\n";
				print "\n";
			}
		
			exit;
		}
		elsif ( $sel eq "2" )
		{
			system("cls");
			print "\n\n";
			print ".:: Needed Parameters ::.","\n";
			print "---------------------------------","\n";
			print "Parameter           Value       ","\n";
			print "---------------------------------","\n";
			print "User ID             ";
			chomp(my $id = <STDIN>);	
			print "Program             ";
			chomp(my $prog = <STDIN>);
			print "\n\n";
			print "++++++++++ Paths Found ++++++++++\n";
			
			#get latest run directory to search in
			$id = IAD::MiscFunc::trim($id);
			$prog = IAD::MiscFunc::trim($prog);
			$prog =~ s/^P/J/;
			
			#get latest directory
			my @jdew_smwe = bsd_glob("$cwd\\..\\jdew.smwe.*");
			my($lmon,$lday,$lyr,$lhr,$lmin,$lsec) = (1,1,1,0,0,0); #latest time
			my $latest;
			for my $dir (@jdew_smwe)
			{
				my($per1,$per2,$jdew,$loc,$mon,$day,$yr,$hr,$min,$sec) = split /\./, $dir;
				my($dir_name,$dir_path,$dir_suffix) = fileparse($dir,qr()) or die "Can't parse $dir\n";
			
				#make amends for adding 1 in IAD::MiscFunc::get_timestamp()
				$mon -= 1;
	
				my $time1 = timelocal($lsec,$lmin,$lhr,$lday,$lmon,$lyr);
				my $time2 = timelocal($sec,$min,$hr,$day,$mon,$yr);
				my $diff  = $time1 - $time2;
	
				if ( $diff < 0 )
				{
					#currently stored latest is earlier than currently procesed date, change latest to current
					$latest = $dir_name;
					($lmon,$lday,$lyr,$lhr,$lmin,$lsec) = ($mon,$day,$yr,$hr,$min,$sec);		
				}
			}		
			unless ($latest) { print "No Directories Found!\n\n"; exit; }
			
			#get menu tree file for the user ID specified
			my $file = "$cwd\\..\\$latest\\menu_trees\\$id.csv";
			if (-e $file) 
			{
				#open file and search for job
				open MT, "$file"
					or die "Can't open the user's menu tree file ($file): $!\n";
				my $i = 1;
				while (<MT>)
				{
					chomp;					
					my($job,$ver,$path) = split/\|/;
					if ( lc($prog) eq lc($job) )
					{
						print "Path $i:\n";
						print "\tVersion: $ver\n\n";
						my @path = split/\s+/, $path;
						for my $p ( @path )
						{
							print "\t$p\n";						
						}
					    print "\n";
						$i++;
					}
				}				
				close MT;				
			}
			else
			{
				print "User ID :: $id\n";
				print "Can't locate this profile's file ($file)\n";
				print "in the latest directory($latest).\n";
				print "\n";
				print "Are you sure this profile is *ENABLED and has access to production data?\n";
				print "Either way...this profile does not have a menu tree for the latest run.\n";
				print "\n";
			}
		
			exit;			
		}
	
	}
	elsif ( $sel eq "4" )
	{
		#list and auto guess latest HQ JDE world diff directory
		system("cls");
		print "\n\n";		
		my($lmon,$lday,$lyr,$lhr,$lmin,$lsec);   #vars to hold latest time stamps
		my $latest;                              #hold latest directory
			
		print "+++++ JDE HQ Directories +++++","\n";
		my @jdew_hq = bsd_glob ("$cwd\\..\\jdew.hq.*");
		($lmon,$lday,$lyr,$lhr,$lmin,$lsec) = (1,1,1,0,0,0); #latest time
		for my $dir (@jdew_hq)
		{
			my($per1,$per2,$jdew,$loc,$mon,$day,$yr,$hr,$min,$sec) = split /\./, $dir;
			my($dir_name,$dir_path,$dir_suffix) = fileparse($dir,qr()) or die "Can't parse $dir\n";
			print "$dir_name\n";
			
			#make amends for adding 1 in IAD::MiscFunc::get_timestamp()
			$mon -= 1;
	
			my $time1 = timelocal($lsec,$lmin,$lhr,$lday,$lmon,$lyr);
			my $time2 = timelocal($sec,$min,$hr,$day,$mon,$yr);
			my $diff  = $time1 - $time2;
	
			if ( $diff < 0 )
			{
				#currently stored latest is earlier than currently procesed date, change latest to current
				$latest = $dir_name;
				($lmon,$lday,$lyr,$lhr,$lmin,$lsec) = ($mon,$day,$yr,$hr,$min,$sec);		
			}
		}	
		print "\n";
		unless ($latest) { $latest = "No Directories!"; }
		print "Latest JDE HQ directory: $latest\n\n";
		undef $latest;
			
		print "\n\n";
		
		#list and auto guess latest JDE SMWE world diff directory
		print "+++++ JDE SMWE Directories +++++","\n";
		my @jdew_smwe = bsd_glob ("$cwd\\..\\jdew.smwe.*");
		($lmon,$lday,$lyr,$lhr,$lmin,$lsec) = (1,1,1,0,0,0); #latest time
		for my $dir (@jdew_smwe)
		{
			my($per1,$per2,$jdew,$loc,$mon,$day,$yr,$hr,$min,$sec) = split /\./, $dir;
			my($dir_name,$dir_path,$dir_suffix) = fileparse($dir,qr()) or die "Can't parse $dir\n";
			print "$dir_name\n";
			
			#make amends for adding 1 in IAD::MiscFunc::get_timestamp()
			$mon -= 1;
	
			my $time1 = timelocal($lsec,$lmin,$lhr,$lday,$lmon,$lyr);
			my $time2 = timelocal($sec,$min,$hr,$day,$mon,$yr);
			my $diff  = $time1 - $time2;
	
			if ( $diff < 0 )
			{
				#currently stored latest is earlier than currently procesed date, change latest to current
				$latest = $dir_name;
				($lmon,$lday,$lyr,$lhr,$lmin,$lsec) = ($mon,$day,$yr,$hr,$min,$sec);		
			}
		}	
		print "\n";
		unless ($latest) { $latest = "No Directories!"; }
		print "Latest JDE SMWE directory: $latest\n\n";
		undef $latest;	
	}
	elsif ( $sel eq "5" )
	{
		#========================
		# 5. GL Approval Tree Report
		#========================
		MENU_LVL_JDEW_GLTREE:
		system("cls");
		print "\n\n";
		print "1. HQ","\n";
		print "2. Winery","\n";
		print "\n";
		print "Enter Selection: ";
		chomp( $sel = <STDIN> );
	
		#error check
		unless ( $sel eq "1" || $sel eq "2" ) 
	    {
			print "\n";
			print "Invalid selection...try again.","\n";
			undef $sel;
			goto MENU_LVL_JDEW_GLTREE;
	    }
			
		if ( $sel eq "1" )
		{			
			system("cls");
			print "\n\n";
			print ".:: Needed Parameters ::.","\n";
			print "---------------------------------","\n";
			print "Parameter           Value       ","\n";
			print "---------------------------------","\n";
			print "User ID             ";
			chomp(my $id = <STDIN>);	
			my $pass = read_password('Password            ');				
			print "\n\n";
			system("jde_hq_approval_tree.exe $id $pass c:\\jde_program");
			print "\n";
			print "Saved file to: c:\\jde_program\\approval_tree.xls";
			print "\n\n\n";
			print "Processing Complete!";
			print "\n\n";
			print "Have a day now :-)!\n";
			exit;
		}
		elsif ( $sel eq "2" )
		{
			system("cls");
			print "\n\n";
			print ".:: Needed Parameters ::.","\n";
			print "---------------------------------","\n";
			print "Parameter           Value       ","\n";
			print "---------------------------------","\n";
			print "User ID             ";
			chomp(my $id = <STDIN>);	
			my $pass = read_password('Password            ');				
			print "\n\n";
			system("jde_smwe_approval_tree.exe $id $pass c:\\jde_program");
			print "\n";
			print "Saved file to: c:\\jde_program\\approval_tree.xls";
			print "\n\n\n";
			print "Processing Complete!";
			print "\n\n";
			print "Have a day now :-)!\n";
			exit;
		}
	}
	elsif ( $sel eq "6" )
	{
		print "\n\n";
		print "+========================+","\n";
		print "+ Ending this session... +","\n";
		print "+========================+","\n";
		print "Goodbye you yellow belly...\n";
		print "\n\n";
		exit;
	}
	
} #end main()

#=========
# Functions
#=========
sub interrupt
{
	print "\n\n\n\n\n";
	print "+========================+","\n";
	print "+ Ending this session... +","\n";
	print "+========================+","\n";
	print "\n";
	print "Have a nice day douchebag!\n";
	print "\n";
	exit;

}