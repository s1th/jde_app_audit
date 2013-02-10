#======================================================
#               .: JDEwConf Module :.
#
# This module parses the 'JDEw.conf' configuration file
# and stores the configuration details in the '%conf'
# hash.  This configuration file must be stored
# in the same location as the script, or you will
# get an error that it can't find the file.
#======================================================
package JDEwConf;
require Exporter;

use strict;
use warnings;
use DBI;
use DBD::ODBC;
use Date::Calc qw( Date_to_Days );

our (@ISA, @EXPORT);
@ISA = qw(Exporter);
@EXPORT= qw(%conf %hq_loc);

#=================
# Global Variables
#=================
our %conf;   #hold all configuration information
our %hq_loc; #hold location information for the Corporate HQ system [jdesec DSN]

#==================================
# Open and parse configuration file
#==================================
sub get_conf
{
	#get configuration
	open CONF, "JDEw.conf"
		or die "\n\nError in JDEwConf::get_conf(): cannot open the jde_w.conf file.\nMake sure the jde_w.conf file is in the current working directory.\n";
	while (<CONF>)
	{
		chomp;
		my $line = $_;
		if ( $line =~ /^#.*/ || $line =~ /^(\s)*$/ ) { next; } #skip comments and blanks
		my($d1,$d2,$d3,$d4) = split/\|/;
		if ($d1 eq "CF")
		{
			#critical files location - example line: CF|jdesec|F0093|ustsec
			$conf{$d2}->{$d1}->{$d3} = $d4;			
		}
		elsif ($d1 eq "LD")
		{
			#level deep setting - example line: LD|jdesec|30
			$conf{$d2}->{$d1} = $d3;			
		}
		elsif ($d1 eq "CP")
		{
			#critical programs - example line: CP|jdesec|P4211|AC
			$d3 =~ s/^P/J/;
			$conf{$d2}->{$d1}->{$d3} = lc($d4);
		}
	}
} #get_conf()

#===============================================
# Update location information for "jdesec" DSN - e.g. 
# corporate HQ
#===============================================
sub update_location_info
{
	my %ui;       #query info 
	my %to_add;   #hold any ids to add to the configuration file
	my $connstr;
	my $dbh;
	my $sth;
	my $sql;

	unless ( $main::offline_dir )
	{
		#update new profiles
		my $connstr = "dbi:ODBC:" . "$main::dsn";
		my $dbh = DBI->connect($connstr,$main::id,$main::pwd);
		if (!$dbh)
		{
			print "Error in JDEwConf::update_location_info(): Can't connect to database.\n";			
			print "\n";
			exit;
		}
	
		#first try to delete the current users_info file on the 400
		$sql = "call qcmdexc('dltf file(audtlib/users_info)',0000000029.00000)";
		$sth = $dbh->prepare($sql);
		$sth->execute or warn "audtlib/users_info unsuccessfully deleted, probably didn't exist...\n";
			
		#now create the users_info file
		$sql = "call qcmdexc('audusrprf users_info',0000000020.00000)";
		$sth = $dbh->prepare($sql);
		$sth->execute or warn "cound't execute audusrprf...\n";
			
		#create the query
		$sql = "
		        select upuprf,uptext,upgrpf,upstat
		        from audtlib.users_info
		       ";
		$sth = $dbh->prepare($sql);
		$sth->execute or warn "cound't execute audusrprf...\n";

		while (my($upuprf,$uptext,$upgrpf,$upstat) = $sth->fetchrow)
		{
			$upuprf = IAD::MiscFunc::trim($upuprf);
			$uptext = IAD::MiscFunc::trim($uptext);
			$upgrpf = IAD::MiscFunc::trim($upgrpf);
			$upstat = IAD::MiscFunc::trim($upstat);
		
			#store
			$ui{$upuprf}->{name}   = $uptext;
			$ui{$upuprf}->{group}  = $upgrpf;
			$ui{$upuprf}->{status} = $upstat;		
		}	
		$sth->finish;
	}
	else
	{
		#offline processing		
		open UINFO, "$main::offline_dir\\data\\users_info.csv"
	        or die "can't open the users_info.csv file: $!\n";
		while (<UINFO>)
		{
			chomp;
			my($id,$name,$group,$status) = split/\|/;
			$id     = IAD::MiscFunc::trim($id);
			$name   = IAD::MiscFunc::trim($name);
			$group  = IAD::MiscFunc::trim($group);
			$status = IAD::MiscFunc::trim($status);
			
			#store
			$ui{$id}->{name}   = $name;
			$ui{$id}->{group}  = $group;
			$ui{$id}->{status} = $status;
		}
		close UINFO;
	}
		
	#get current user location information
	open LOC, "$conf{ $main::dsn }->{CF}->{LOC_FILE}"
		or die "Can't open the Corporate HQ users location file: $!\n";
	while (<LOC>)
	{
		chomp;
		if ($_ =~ /^#.*/) { next; }
		if ($_ =~ /^$/)   { next; }
		my($id,$loc,$group) = split/\|/;
		$hq_loc{$id}->{loc} = $loc;
	}
	close LOC;
	
	#add in any new users!
	for my $id ( keys %ui )
	{
		unless ( ( lc( $ui{$id}->{status} ) eq "*enabled" )  && ( lc( $ui{$id}->{group} ) eq "jde" ) ) { next; } #only add in *enabled and JDE user profiles
		my $name = $ui{$id}->{name};
		
		if ( $hq_loc{$id} ) 
		{ 
			#already exists			
			next; 
		}
		else
		{
			#user doesn't have a location!
			if ( 
				$name =~ /^.*franklin park.*$/ig
				|| $name =~ /^.*frkln pk.*$/ig
				|| $name =~ /^.*fpk.*$/ig
				|| $name =~ /^.*frk pk.*$/ig 
			   )
			{
				my $loc = "Franklin_Park";
				$hq_loc{$id}->{loc} = $loc;
			
				#add to the to_add hash
				$to_add{$id}->{loc} = $loc;	
			}
			elsif ( 
					$name =~ /^.*corp.*$/ig 
					|| $name =~ /^.*greenwich.*$/ig
					|| $name =~ /^.*HQ.*$/g
					|| $name =~ /^.*100.*WPA.*$/ig
					|| $name =~ /^.*599.*GOP.*$/ig					
					|| $name =~ /^.*IS Dev.*$/ig
					|| $name =~ /^.*Develop.*$/ig					
				  )
			{
				my $loc = "Corporate";
				$hq_loc{$id}->{loc} = $loc;
			
				#add to the to_add hash
				$to_add{$id}->{loc} = $loc;
			}
			elsif ( 
					$name =~ /^.*nsh.*$/ig 
					|| $name =~ /^.*nashville.*$/ig
				  )
			{
				my $loc = "Nashville";
				$hq_loc{$id}->{loc} = $loc;
			
				#add to the to_add hash
				$to_add{$id}->{loc} = $loc;
			}
			elsif ( 
					$name =~ /^.*hop.*$/ig 
					|| $name =~ /^.*hopkinsville.*$/ig
				  )
			{
				my $loc = "Hopkinsville";
				$hq_loc{$id}->{loc} = $loc;
			
				#add to the to_add hash
				$to_add{$id}->{loc} = $loc;	
			}
			elsif ( 
					$name =~ /^.*region.*$/ig 
				  )
			{
				my $loc = "Region";
				$hq_loc{$id}->{loc} = $loc;
			
				#add to the to_add hash
				$to_add{$id}->{loc} = $loc;	
			}
			elsif ( 
					$name =~ /^.*rickard.*$/ig 
					|| $name =~ /^.*rickard seed.*$/ig
				  )
			{
				my $loc = "Rickard_Seed";
				$hq_loc{$id}->{loc} = $loc;
			
				#add to the to_add hash
				$to_add{$id}->{loc} = $loc;				
			}
			elsif ( 
					$name =~ /^.*clarksville.*$/ig 
					|| $name =~ /^.*cadiz.*$/ig
				  )
			{
				my $loc = "Clarksville";
				$hq_loc{$id}->{loc} = $loc;
			
				#add to the to_add hash
				$to_add{$id}->{loc} = $loc;		
			}
			else
			{
				my $loc = "No_Location";
				$hq_loc{$id}->{loc} = $loc;
			
				#add to the to_add hash
				$to_add{$id}->{loc} = $loc;		
			}
		}
	}
	
	#add any new users to the configuration file
	my @add_keys = keys %to_add;
	if ( @add_keys )
	{
		open ADD, ">>$conf{ $main::dsn }->{CF}->{LOC_FILE}"
			or die "Can't open the $conf{ $main::dsn }->{CF}->{LOC_FILE} file to add members: $!\n";
		print ADD "\n\n";
		print ADD "# Added during $main::ts run\n";
		
		#add in the ones found
		for my $id (sort keys %to_add)
		{
			print ADD "$id|";
			print ADD $to_add{$id}->{loc} . "\n";
		}
		close ADD;
	}

	#clear memory
	%ui = ();
	
} #update_location_info()

#=======
#Return 1
#=======
1;