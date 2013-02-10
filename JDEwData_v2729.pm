#============================================================
# .:: JDEwData module ::.
#
#Purpose: module responsible for handling all of the storing/retrieving
# of any necessary data.
#
#============================================================
package JDEwData;
use strict;
use DBI;
use DBD::ODBC;
use IAD::MiscFunc;
use IAD::XL;
use File::Path;
use Storable;

our (@ISA, @EXPORT);
@ISA = qw(Exporter);
@EXPORT= qw($topd $datad $logd $outd $mtd);

#=========
#Class data
#=========
#db stuff
my $dbh;            #database handle
my $sth;            #statement handle
my $sql;            #sql statements
my $lib;            #library (diff based on co)
my $id;             #AS400 user id
my $pwd;            #AS400 password
my $dsn;            #ODBC data source for server being audited

#configuration
our $topd;	#top level 
our $datad; #data files
our $logd;  #log files
our $outd;  #output files
our $mtd;   #dir to hold menu trees store data

#data
my %ms;             #menu selections data - see get_menu_selections()
my %as;             #advanced screens menu selections - see get_menu_selections()
my %ss;             #setup screens menu selections - see get_menu_selections()
my %id;             #user ids initial menu data - see get_init_menu() +
                    #                                 get_user_data()
my %gp;             #group and their keys - see get_f0092()
my %pb;             #*PUBLIC group and their keys - see get_user_data
my %ol;             #overall menu locks hash - see get_overall_locks()
my %am;             #advanced menus hash - see get_overall_locks()
my %sm;             #setup menus hash - see get_overall_locks()
my %hs;             #zhidden menus selections data - see get_hs()
my %fk;             #function key security - see get_fk()
my %st;				#search type security - see get_st()
my %ac;             #action code security - see get_ac()
my %pd;				#program descriptions data - see get_pd()
my %ui;				#users_info file from audusrprf - see get_ui()
my $pub = "*PUBLIC"; #for *PUBLIC analysis
my $all = "*ALL";    #for *ALL analysis
my $st  = "ST";      #search type key for %ac - see get_ac()
my $connstr;         #connection string for db stuff

#locks test variables
my $ranking_values      = " 9876543210ZYXWVUTSRQPONMLKJIHGFEDCBA";  #menu locks
my $user_ranking_values = "x9876543210ZYXWVUTSRQPONMLKJIHGFEDCBA "; #user locks
my $oma_ind;         #overall a mask index
my $omj_ind;         #j
my $omk_ind;         #k
my $omd_ind;         #d
my $omf_ind;         #f

#==========
#Constructor
#==========
sub spawn
{
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my $self  = {};
	($id,$pwd,$dsn) = @_;
	bless($self,$class);
	return $self;
}

#===================
#Open database handle
#===================
sub open_db
{
	unless ( $main::offline_dir )
	{
		my $self = shift;
		$connstr = "dbi:ODBC:" . "$dsn";
		$dbh = DBI->connect($connstr,$id,$pwd);
		if (!$dbh)
		{
			print "Error in JDEwData::open_db(): cannot open the database handle.";
			print "Check that the DSN ($dsn) exists in ODBC Admin, and that the\n";
			print "username ($id) and password ($pwd) are correct.\n";
			print "\n";
			exit;
		}
	}
}

#===================
#Close database handle
#===================
sub close_db
{
	unless ( $main::offline_dir )
	{
		if (!$dbh)
		{
			print "Error in JDEwData::close_db(): no database handle exists.";
			print "\n";
			exit;
		}
		else
		{
			$dbh->disconnect;
		}
	}
}

#================
#Create directories
#================
sub create_dirs
{
	my $name;
	
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
	
	$topd = $main::cwd . "\\jdew." . $name . "." . "$main::ts";
	mkdir($topd);
	
	$datad = $topd . "\\data";
	mkdir($datad);
	
	$logd = $topd . "\\log";
	mkdir($logd);
	
	$outd = $topd . "\\output";
	mkdir($outd);
	
	$mtd = $topd . "\\menu_trees";
	mkdir($mtd);
}

#=================================================
#Menu Selections - Menus, Advanced Menus, Setup Menus
#=================================================
sub get_menu_selections
{
	#get F00821 table for these queries
	my $table = $JDEwConf::conf{$dsn}->{CF}->{F00821};
	
	unless ( $main::offline_dir )
	{
		#f00821 query - exclude % menus (used by robot)
		#query
		$sql="
				select mzmni,mzseln,mzmska,mzmskd,mzmskj,mzmskk,mzmskf,mzjtoe,
				mzver,mzmtoe,mzsbtd
				from $table.f00821
				where substr(mzmni,1,1) != '%'
				order by mzmni,mzseln
			";
		$sth = $dbh->prepare($sql);
		$sth->execute;

		#data file
		open F821, ">$datad\\f00821.csv"
			or die "can't open the f00821 data file: $!";
		while (my($mzmni,$mzseln,$mzmska,$mzmskd,$mzmskj,$mzmskk,$mzmskf,$mzjtoe,
				  $mzver,$mzmtoe,$mzsbtd) = $sth->fetchrow)
		{
			#clean up
			$mzmni  = IAD::MiscFunc::trim($mzmni);
			$mzseln = IAD::MiscFunc::trim($mzseln);
			$mzmska = IAD::MiscFunc::trim($mzmska);
			$mzmskd = IAD::MiscFunc::trim($mzmskd);
			$mzmskj = IAD::MiscFunc::trim($mzmskj);
			$mzmskk = IAD::MiscFunc::trim($mzmskk);
			$mzmskf = IAD::MiscFunc::trim($mzmskf);
			$mzjtoe = IAD::MiscFunc::trim($mzjtoe);
			$mzver  = IAD::MiscFunc::trim($mzver);
			$mzmtoe = IAD::MiscFunc::trim($mzmtoe);
			$mzsbtd = IAD::MiscFunc::trim($mzsbtd);
			
			$ms{$mzmni}->{$mzseln}->{a} = $mzmska;
			$ms{$mzmni}->{$mzseln}->{d} = $mzmskd;
			$ms{$mzmni}->{$mzseln}->{j} = $mzmskj;
			$ms{$mzmni}->{$mzseln}->{k} = $mzmskk;
			$ms{$mzmni}->{$mzseln}->{f} = $mzmskf;
			$ms{$mzmni}->{$mzseln}->{jexc} = $mzjtoe;
			$ms{$mzmni}->{$mzseln}->{jver} = $mzver;
			$ms{$mzmni}->{$mzseln}->{mexc} = $mzmtoe;
			$ms{$mzmni}->{$mzseln}->{batv} = $mzsbtd;
			print F821 "$mzmni|$mzseln|$mzmska|$mzmskd|$mzmskj|$mzmskk|$mzmskf|$mzjtoe|" .
					   "$mzver|$mzmtoe|$mzsbtd\n";
		}
		close F821;
		$sth->finish;
	}
	else
	{
		#offline processing 
		open F821, "$main::offline_dir\\data\\f00821.csv"
			or die "Can't open the f00821 file ($main::offline_dir\\data\\f00821.csv): $!\n";
		while (<F821>)
		{
			chomp;
			my($mzmni,$mzseln,$mzmska,$mzmskd,$mzmskj,$mzmskk,$mzmskf,$mzjtoe,$mzver,$mzmtoe,$mzsbtd) = split/\|/;
			
			$ms{$mzmni}->{$mzseln}->{a} = $mzmska;
			$ms{$mzmni}->{$mzseln}->{d} = $mzmskd;
			$ms{$mzmni}->{$mzseln}->{j} = $mzmskj;
			$ms{$mzmni}->{$mzseln}->{k} = $mzmskk;
			$ms{$mzmni}->{$mzseln}->{f} = $mzmskf;
			$ms{$mzmni}->{$mzseln}->{jexc} = $mzjtoe;
			$ms{$mzmni}->{$mzseln}->{jver} = $mzver;
			$ms{$mzmni}->{$mzseln}->{mexc} = $mzmtoe;
			$ms{$mzmni}->{$mzseln}->{batv} = $mzsbtd;
		}
		close F821;
	}
	
	unless ( $main::offline_dir )
	{
		#get advanced menus selections
		#query
		$sql="
				select mzmni,mzseln,mzmska,mzmskd,mzmskj,mzmskk,mzmskf,mzjtoe,
				mzver,mzmtoe,mzsbtd
				from $table.f00821
				where mzmni in (select distinct mnxmn from $table.f0082)
			";
		$sth = $dbh->prepare($sql);
		$sth->execute;

		#data file
		open ADV, ">$datad\\f00821_adv.csv"
			or die "can't open the f00821_adv data file: $!";

		while (my($mzmni,$mzseln,$mzmska,$mzmskd,$mzmskj,$mzmskk,$mzmskf,$mzjtoe,
				  $mzver,$mzmtoe,$mzsbtd) = $sth->fetchrow)
		{
			#clean up
		 	$mzmni  = IAD::MiscFunc::trim($mzmni);
		 	$mzseln = IAD::MiscFunc::trim($mzseln);
		 	$mzmska = IAD::MiscFunc::trim($mzmska);
		 	$mzmskd = IAD::MiscFunc::trim($mzmskd);
		 	$mzmskj = IAD::MiscFunc::trim($mzmskj);
		 	$mzmskk = IAD::MiscFunc::trim($mzmskk);
		 	$mzmskf = IAD::MiscFunc::trim($mzmskf);
		 	$mzjtoe = IAD::MiscFunc::trim($mzjtoe);
		 	$mzver  = IAD::MiscFunc::trim($mzver);
		 	$mzmtoe = IAD::MiscFunc::trim($mzmtoe);
			$mzsbtd = IAD::MiscFunc::trim($mzsbtd);

			$as{$mzmni}->{$mzseln}->{a} = $mzmska;
			$as{$mzmni}->{$mzseln}->{d} = $mzmskd;
			$as{$mzmni}->{$mzseln}->{j} = $mzmskj;
			$as{$mzmni}->{$mzseln}->{k} = $mzmskk;
			$as{$mzmni}->{$mzseln}->{f} = $mzmskf;
			$as{$mzmni}->{$mzseln}->{jexc} = $mzjtoe;
			$as{$mzmni}->{$mzseln}->{jver} = $mzver;
			$as{$mzmni}->{$mzseln}->{mexc} = $mzmtoe;
			$as{$mzmni}->{$mzseln}->{batv} = $mzsbtd;
			
			print ADV "$mzmni|$mzseln|$mzmska|$mzmskd|$mzmskj|$mzmskk|$mzmskf|$mzjtoe|" .
					  "$mzver|$mzmtoe|$mzsbtd\n";
		}
		close ADV;
		$sth->finish;
	}
	else
	{
		#offline processing
		open ADV, "$main::offline_dir\\data\\f00821_adv.csv"
			or die "Can't open the f00821_adv file ($main::offline_dir\\data\\f00821_adv.csv): $!\n";
		while (<ADV>)
		{
			chomp;
			my($mzmni,$mzseln,$mzmska,$mzmskd,$mzmskj,$mzmskk,$mzmskf,$mzjtoe,$mzver,$mzmtoe,$mzsbtd) = split/\|/;
			
			$as{$mzmni}->{$mzseln}->{a} = $mzmska;
			$as{$mzmni}->{$mzseln}->{d} = $mzmskd;
			$as{$mzmni}->{$mzseln}->{j} = $mzmskj;
			$as{$mzmni}->{$mzseln}->{k} = $mzmskk;
			$as{$mzmni}->{$mzseln}->{f} = $mzmskf;
			$as{$mzmni}->{$mzseln}->{jexc} = $mzjtoe;
			$as{$mzmni}->{$mzseln}->{jver} = $mzver;
			$as{$mzmni}->{$mzseln}->{mexc} = $mzmtoe;
			$as{$mzmni}->{$mzseln}->{batv} = $mzsbtd;
		}
		close ADV;
	}

	unless ( $main::offline_dir )
	{
		#get setup menus selections
		#query
		$sql="
				select mzmni,mzseln,mzmska,mzmskd,mzmskj,mzmskk,mzmskf,mzjtoe,
				mzver,mzmtoe,mzsbtd
				from $table.f00821
				where mzmni in (select distinct mnocmn from $table.f0082)
			";
		$sth = $dbh->prepare($sql);
		$sth->execute;

		#data file
		open SET, ">$datad\\f00821_set.csv"
			or die "can't open the f00821_set data file: $!";

		while (my($mzmni,$mzseln,$mzmska,$mzmskd,$mzmskj,$mzmskk,$mzmskf,$mzjtoe,
				  $mzver,$mzmtoe,$mzsbtd) = $sth->fetchrow)
		{
			#clean up
			$mzmni  = IAD::MiscFunc::trim($mzmni);
		 	$mzseln = IAD::MiscFunc::trim($mzseln);
		 	$mzmska = IAD::MiscFunc::trim($mzmska);
		 	$mzmskd = IAD::MiscFunc::trim($mzmskd);
		 	$mzmskj = IAD::MiscFunc::trim($mzmskj);
		 	$mzmskk = IAD::MiscFunc::trim($mzmskk);
		 	$mzmskf = IAD::MiscFunc::trim($mzmskf);
		 	$mzjtoe = IAD::MiscFunc::trim($mzjtoe);
		 	$mzver  = IAD::MiscFunc::trim($mzver);
		 	$mzmtoe = IAD::MiscFunc::trim($mzmtoe);
			$mzsbtd = IAD::MiscFunc::trim($mzsbtd);

			$ss{$mzmni}->{$mzseln}->{a} = $mzmska;
			$ss{$mzmni}->{$mzseln}->{d} = $mzmskd;
			$ss{$mzmni}->{$mzseln}->{j} = $mzmskj;
			$ss{$mzmni}->{$mzseln}->{k} = $mzmskk;
			$ss{$mzmni}->{$mzseln}->{f} = $mzmskf;
			$ss{$mzmni}->{$mzseln}->{jexc} = $mzjtoe;
			$ss{$mzmni}->{$mzseln}->{jver} = $mzver;
			$ss{$mzmni}->{$mzseln}->{mexc} = $mzmtoe;
			$ss{$mzmni}->{$mzseln}->{batv} = $mzsbtd;
			
			print SET "$mzmni|$mzseln|$mzmska|$mzmskd|$mzmskj|$mzmskk|$mzmskf|$mzjtoe|" .
					  "$mzver|$mzmtoe|$mzsbtd\n";
		}
		close SET;
		$sth->finish;
	}
	else
	{
		#offline processing
		open SET, "$main::offline_dir\\data\\f00821_set.csv"
			or die "Can't open the f00821_set file ($main::offline_dir\\data\\f00821_set.csv): $!\n";
		while (<SET>)
		{
			chomp;
			my($mzmni,$mzseln,$mzmska,$mzmskd,$mzmskj,$mzmskk,$mzmskf,$mzjtoe,$mzver,$mzmtoe,$mzsbtd) = split/\|/;
		
			$ss{$mzmni}->{$mzseln}->{a} = $mzmska;
			$ss{$mzmni}->{$mzseln}->{d} = $mzmskd;
			$ss{$mzmni}->{$mzseln}->{j} = $mzmskj;
			$ss{$mzmni}->{$mzseln}->{k} = $mzmskk;
			$ss{$mzmni}->{$mzseln}->{f} = $mzmskf;
			$ss{$mzmni}->{$mzseln}->{jexc} = $mzjtoe;
			$ss{$mzmni}->{$mzseln}->{jver} = $mzver;
			$ss{$mzmni}->{$mzseln}->{mexc} = $mzmtoe;
			$ss{$mzmni}->{$mzseln}->{batv} = $mzsbtd;
		}
		close SET;
	}

	return (\%ms,\%as,\%ss);
}

#==========================================
#Initial Menu for a Production Data User - F0093
#==========================================
sub get_init_menu
{
	my $table = $JDEwConf::conf{$dsn}->{"CF"}->{"F0093"};
	my $self = shift;
	$self->get_ui;

	unless ( $main::offline_dir )
	{
		#query
		if ($main::dsn eq "jdesec")
		{
			$sql = "
					select lluser,llll,llmni
					from $table.f0093
					where llll = 'PRODUCTION' or llll = 'PRODAUDIT'
					order by lluser
				   ";
		}
		elsif ($main::dsn eq "slsec")
		{
			$sql = "
					select lluser,llll,llmni
					from $table.f0093
					where llll = 'PROD'
					order by lluser
				   ";		
		}
		else
		{
			$sql = "
					select lluser,llll,llmni
					from $table.f0093					
					order by lluser
				   ";		
		}
		
		$sth = $dbh->prepare($sql);
		$sth->execute;

		#data file
		open F93, ">$datad\\f0093.csv"
			or die "can't open the f0093 data file: $!";
		while (my($lluser,$llll,$llmni) = $sth->fetchrow)
		{
			$lluser = IAD::MiscFunc::trim($lluser);
			$llll   = IAD::MiscFunc::trim($llll);
			$llmni  = IAD::MiscFunc::trim($llmni);

			#store in id hash
			if ($main::dsn eq "jdesec")
			{
				if ( (lc( $ui{$lluser}->{status} ) eq "*enabled") && (lc( $ui{$lluser}->{group} ) eq "jde") )
				{
					$id{$lluser}->{init} = $llmni;
					print F93 "$lluser|$llll|$llmni\n";
				}			
			}
			elsif ($main::dsn eq "slsec")
			{
				if ( (lc( $ui{$lluser}->{status} ) eq "*enabled") && (lc( $ui{$lluser}->{group} ) eq "jdeprd") )
				{
					$id{$lluser}->{init} = $llmni;
					print F93 "$lluser|$llll|$llmni\n";
				}			
			}
			else
			{
				if (lc( $ui{$lluser}->{status} ) eq "*enabled")
				{
					$id{$lluser}->{init} = $llmni;
					print F93 "$lluser|$llll|$llmni\n";
				}
			}
		}
		close F93;
		$sth->finish;
	}
	else
	{
		#offline processing
		open F93, "$main::offline_dir\\data\\f0093.csv"
			or die "Can't open the f0093.csv file ($main::offline_dir\\data\\f0093.csv): $!\n";
		while (<F93>)
		{
			chomp;
			my($lluser,$llll,$llmni) = split/\|/;
			$lluser = IAD::MiscFunc::trim($lluser);
			$llll   = IAD::MiscFunc::trim($llll);
			$llmni  = IAD::MiscFunc::trim($llmni);
			
			if ($main::dsn eq "jdesec")
			{
				if ( (lc( $ui{$lluser}->{status} ) eq "*enabled") && (lc( $ui{$lluser}->{group} ) eq "jde") )
				{
					$id{$lluser}->{init} = $llmni;
				}	
			}
			elsif ($main::dsn eq "slsec")
			{
				if ( (lc( $ui{$lluser}->{status} ) eq "*enabled") && (lc( $ui{$lluser}->{group} ) eq "jdeprd") )
				{
					$id{$lluser}->{init} = $llmni;
				}
			}
			else
			{
				if (lc( $ui{$lluser}->{status} ) eq "*enabled")
				{
					$id{$lluser}->{init} = $llmni;
				}
			}
		}
		close F93;
	}
}

#================================================
#User Data Function - F0092 and Build of Composite Key 
#================================================
sub get_user_data
{
	my $self = shift;
	$self->get_init_menu;
	my $table = $JDEwConf::conf{$dsn}->{"CF"}->{"F0092"};;

	unless ( $main::offline_dir )
	{
		#query
		$sql="
				select uluser,ulugrp,ulmska,ulmskd,ulmskj,ulmskk,ulmskf,
				ulmtvl,ulcmde,ulfstp
				from $table.f0092
				order by uluser
			";
		$sth = $dbh->prepare($sql);
		$sth->execute;

		#data file
		open F92, ">$datad\\f0092.csv"
		     or die "can't open the f0092 data file: $!";
		while (my($uluser,$ulugrp,$ulmska,$ulmskd,$ulmskj,$ulmskk,$ulmskf,$ulmtvl,
		          $ulcmde,$ulfstp) = $sth->fetchrow)
		{
			$uluser = IAD::MiscFunc::trim($uluser);
		 	$ulugrp = IAD::MiscFunc::trim($ulugrp);
		 	$ulmska = IAD::MiscFunc::trim($ulmska);
		 	$ulmskd = IAD::MiscFunc::trim($ulmskd);
		 	$ulmskj = IAD::MiscFunc::trim($ulmskj);
		 	$ulmskk = IAD::MiscFunc::trim($ulmskk);
		 	$ulmskf = IAD::MiscFunc::trim($ulmskf);
		 	$ulmtvl = IAD::MiscFunc::trim($ulmtvl);
		 	$ulcmde = IAD::MiscFunc::trim($ulcmde);
		 	$ulfstp = IAD::MiscFunc::trim($ulfstp);

			if (exists $id{$uluser})
			{
				#user with access to procution data
				$id{$uluser}->{gp} = $ulugrp;
			 	$id{$uluser}->{a}  = $ulmska;
			 	$id{$uluser}->{d}  = $ulmskd;
			 	$id{$uluser}->{j}  = $ulmskj;
			 	$id{$uluser}->{k}  = $ulmskk;
			 	$id{$uluser}->{f}  = $ulmskf;
			 	$id{$uluser}->{mt} = $ulmtvl;
			 	$id{$uluser}->{ce} = $ulcmde;
			 	$id{$uluser}->{fp} = $ulfstp;
			}
			elsif ($uluser eq $pub)
			{
				$pb{$uluser}->{a} = $ulmska;
				$pb{$uluser}->{d} = $ulmskd;
				$pb{$uluser}->{j} = $ulmskj;
				$pb{$uluser}->{k} = $ulmskk;
				$pb{$uluser}->{f} = $ulmskf;
			}
			elsif (substr($uluser,0,1) eq "*")
			{
				#a group
			    $gp{$uluser}->{a} = $ulmska;
			    $gp{$uluser}->{d} = $ulmskd;
			    $gp{$uluser}->{j} = $ulmskj;
			    $gp{$uluser}->{k} = $ulmskk;
			    $gp{$uluser}->{f} = $ulmskf;
			}

			#print data to the outfile
			print F92 "$uluser|$ulugrp|$ulmska|$ulmskd|$ulmskj|$ulmskk|$ulmskf|$ulmtvl|" .
					  "$ulcmde|$ulfstp","\n";
		}
		close F92;
		$sth->finish;
	}
	else
	{
		#offline processing
		open F92, "$main::offline_dir\\data\\f0092.csv"
			or die "Can't open the f0092.csv file ($main::offline_dir\\data\\f0092.csv): $!\n";
		while (<F92>)
		{
			chomp;
			my($uluser,$ulugrp,$ulmska,$ulmskd,$ulmskj,$ulmskk,$ulmskf,$ulmtvl,$ulcmde,$ulfstp) = split/\|/;
		
			if (exists $id{$uluser})
			{
				#user with access to procution data
				$id{$uluser}->{gp} = $ulugrp;
			 	$id{$uluser}->{a}  = $ulmska;
			 	$id{$uluser}->{d}  = $ulmskd;
			 	$id{$uluser}->{j}  = $ulmskj;
			 	$id{$uluser}->{k}  = $ulmskk;
			 	$id{$uluser}->{f}  = $ulmskf;
			 	$id{$uluser}->{mt} = $ulmtvl;
			 	$id{$uluser}->{ce} = $ulcmde;
			 	$id{$uluser}->{fp} = $ulfstp;
			}
			elsif ($uluser eq $pub)
			{
				$pb{$uluser}->{a} = $ulmska;
				$pb{$uluser}->{d} = $ulmskd;
				$pb{$uluser}->{j} = $ulmskj;
				$pb{$uluser}->{k} = $ulmskk;
				$pb{$uluser}->{f} = $ulmskf;
			}
			elsif (substr($uluser,0,1) eq "*")
			{
				#a group
			    $gp{$uluser}->{a} = $ulmska;
			    $gp{$uluser}->{d} = $ulmskd;
			    $gp{$uluser}->{j} = $ulmskj;
			    $gp{$uluser}->{k} = $ulmskk;
			    $gp{$uluser}->{f} = $ulmskf;
			}
		}
		
		close F92;
	}
		
	#set %id to hold composite key
	for my $u (keys %id)
	{
		#get user's group
		my $ug = $id{$u}->{gp};

		#store keys in arrays
		my @usr = ($id{$u}->{a},$id{$u}->{j},$id{$u}->{k},$id{$u}->{d},$id{$u}->{f});
		my @g = ($gp{$ug}->{a},$gp{$ug}->{j},$gp{$ug}->{k},$gp{$ug}->{d},
			     $gp{$ug}->{f});
		my @p = ($pb{$pub}->{a},$pb{$pub}->{j},$pb{$pub}->{k},$pb{$pub}->{d},
			     $pb{$pub}->{f});
		my @masks  = ("a","j","k","d","f");

		#get composite key...
		my $i;
		for($i=0;$i<5;++$i)
		{
			if( $usr[$i] )
			{
				$id{$u}->{$masks[$i]} = $usr[$i];
			}
			elsif( $g[$i] )
			{
				$id{$u}->{$masks[$i]} = $g[$i];
			}
			elsif( $p[$i] )
			{
				$id{$u}->{$masks[$i]} = $p[$i];
			}
			else
			{
				#no mask found
				$id{$u}->{$masks[$i]} = " ";
			}
		}
	}

	return \%id;
}

#==================
#Menu Locks Function
#==================
sub locks
{
 #PARAMETERS (MENU,USER A, USER D, USER J, USER K, USER F, MENU A,
 #            MENU D, MENU J, MENU K, MENU F)
 #
 #The menu masking follows the following logic:
 #
 #There are two types of comparisons in menu masking:
 # 1. direct comparison, which requires an exact match between
 #    the J, DP, or F masks both on the menu AND user profile
 # 2. hierarchical comparison, on the A and K masks on the scale -
 #            A-Z > 0-9 > blank
 #    that is A has greater authority than Z which is greater than 0 which
 #    is greater than 9 which is greater than blank which is no authority.
 #
 #Two rules of thumb to obey!:
 # 1. BLANK IN MENU LOCKS = NO SECURITY ON THAT MENU OR SELECTION
 # 2. BLANK IN USER KEY = ALL AUTHORITY FOR THE USER
 #
 #The system checks each lock/key field beginning with A, then J, K, DP,
 #and F; must pass all five to have access!  If the system finds an instance
 #that disallows access, the system stops the search and locks out the user.
 #These masks apply to fast path also!
 #
 #How I handle menu masking analysis based on the above:
 #menu index of 0  = no menu mask - NO SECURITY
 #user index of 37 = no user mask - ALL ACCESS
 #system checks in this order: A, J, K, D, F
 #logic:
 #1. for hierarchical comparisons we do a >=, if the menu lock
 #is blank (indicating no security) the index value returned will be 0
 #...which any possible user index value in an A or K index will be greater
 #than or equal to...thus handling the blank = no security for the menu
 #lock.  on the flip side, if the user's mask is blank, the index returned
 #will be 37 which is greater than any possible value that could be returned
 #from a menu's index value (the array is only 0-36).  thus in any comparison
 #the user's index will be greater than or equal to the menu's index.
 #2. for direct comparison it's more complicated.  If the menu lock is
 #blank, there is no security so the user will be granted access and same
 #for the case where the users' mask is blank...they also will be granted
 #access, because they have all access.  So in this case we have to check
 #three things: if the masks are equal, if the menu's mask is blank, and
 #if the user's mask is blank.  Any one of these cases will pass the user
 #for that particular direct comparison mask.  so these three conditions
 #are checked with an OR...thus any one that's true will return a true for
 #that masks value

 my($self,$menu,$ua,$ud,$uj,$uk,$uf,$ma,$md,$mj,$mk,$mf) = @_;

 print "$self,$menu,$ua,$ud,$uj,$uk,$uf,$ma,$md,$mj,$mk,$mf\n";
 
 #get user indexes
 my $uai = index($user_ranking_values,$ua);
 my $udi = index($user_ranking_values,$ud);
 my $uji = index($user_ranking_values,$uj);
 my $uki = index($user_ranking_values,$uk);
 my $ufi = index($user_ranking_values,$uf);

 #get menu selection indexes
 my $mai = index($ranking_values,$ma);
 my $mdi = index($ranking_values,$md);
 my $mji = index($ranking_values,$mj);
 my $mki = index($ranking_values,$mk);
 my $mfi = index($ranking_values,$mf);

 if ( $ol{$menu} )
 {
  #menu exists in f0082
  #get overall menu locks and indexes
  my $oma = $ol{$menu}->{a};
  my $omd = $ol{$menu}->{d};
  my $omj = $ol{$menu}->{j};
  my $omk = $ol{$menu}->{k};
  my $omf = $ol{$menu}->{f};

  $oma_ind = index($ranking_values,$oma);
  $omj_ind = index($ranking_values,$omj);
  $omk_ind = index($ranking_values,$omk);
  $omd_ind = index($ranking_values,$omd);
  $omf_ind = index($ranking_values,$omf);
 }
 else
 {
  #menu does not exist...so give it no security
  $oma_ind = 0;
  $omj_ind = 0;
  $omk_ind = 0;
  $omd_ind = 0;
  $omf_ind = 0;
 } #end menu's existence check

 #first check the overall menu option locks
 if (
        ($uai >= $oma_ind)
     && ( ($uji == $omj_ind) || ($omj_ind == 0) || $uji == 37 )
     &&   ($uki >= $omk_ind)
     && ( ($udi == $omd_ind) || ($omd_ind == 0) || $udi == 37 )
     && ( ($ufi == $omf_ind) || ($omf_ind == 0) || $ufi == 37 )
    )
 {
	#passed overall menu option locks test
	#now test the menu selection lock
	if (
        ($uai >= $mai)
		&& ( ($uji == $mji) || ($mji == 0) || $uji == 37 )
		&&   ($uki >= $mki)
		&& ( ($udi == $mdi) || ($mdi == 0) || $udi == 37 )
		&& ( ($ufi == $mfi) || ($mfi == 0) || $ufi == 37 )
       )
	{
		#has now passed both locks test, so it passed
		return 1;
	}
	else
	{
		#failed menu options locks test
		return 0;
	}
 }
 else
 {
	#failed at overall menu locks test
	return 0;
 }
} #end sub locks_test

#========================
#Overall Menu Locks - F0082
#========================
sub get_overall_locks
{
	my $table = $JDEwConf::conf{$dsn}->{"CF"}->{"F0082"};;

	unless ( $main::offline_dir )
	{
		#query
		$sql = "
				select mnmni,mnmska,mnmskj,mnmskk,mnmskd,mnmskf,mnxmn,mnocmn
				from $table.f0082
				where substr(mnmni,1,1) != '%'
				order by mnmni
			   ";
		$sth = $dbh->prepare($sql);
		$sth->execute;

		open OL, ">$datad\\f0082.csv"
			or die "can't open the f0082.csv data file: $!\n";
		while (my($menu,$amsk,$jmsk,$kmsk,$dmsk,$fmsk,$adv,$set) = $sth->fetchrow)
		{
			$menu = IAD::MiscFunc::trim($menu);
		 	$amsk = IAD::MiscFunc::trim($amsk);
		 	$jmsk = IAD::MiscFunc::trim($jmsk);
		 	$kmsk = IAD::MiscFunc::trim($kmsk);
		 	$dmsk = IAD::MiscFunc::trim($dmsk);
		 	$fmsk = IAD::MiscFunc::trim($fmsk);
		 	$adv  = IAD::MiscFunc::trim($adv);
		 	$set  = IAD::MiscFunc::trim($set);

			#overall locks hash
			$ol{$menu}->{a} = $amsk;
			$ol{$menu}->{d} = $dmsk;
			$ol{$menu}->{j} = $jmsk;
			$ol{$menu}->{k} = $kmsk;
			$ol{$menu}->{f} = $fmsk;

			#adv jumps
			$am{$menu}->{adv} = $adv;

			#set jumps
			$sm{$menu}->{set} = $set;

			#print data to the outfile
			print OL "$menu|$amsk|$jmsk|$kmsk|$dmsk|$fmsk|$adv|$set","\n";
		}
		
		close OL;
		$sth->finish;
	}
	else
	{
		#offline processing
		open OL, "$main::offline_dir\\data\\f0082.csv"
			or die "Can't open the f0082.csv file ($main::offline_dir\\data\\f0082.csv): $!\n";
		while (<OL>)
		{
			chomp;
			my($menu,$amsk,$jmsk,$kmsk,$dmsk,$fmsk,$adv,$set) = split/\|/;
			
			#overall locks hash
			$ol{$menu}->{a} = $amsk;
			$ol{$menu}->{d} = $dmsk;
			$ol{$menu}->{j} = $jmsk;
			$ol{$menu}->{k} = $kmsk;
			$ol{$menu}->{f} = $fmsk;

			#adv jumps
			$am{$menu}->{adv} = $adv;

			#set jumps
			$sm{$menu}->{set} = $set;
		}
		close OL;
	}

	return (\%ol,\%am,\%sm);
}

#=================================================================================================
#Hidden Selections - ZHIDDEN, ZHIDDEN002, and ZHIDDEN003 menus mainly concerned with 27 and 29 jumps
#=================================================================================================
sub get_hs
{
	#get users who have access to the 27 and 29 adv/set menu jumps
	my $table = $JDEwConf::conf{$dsn}->{"CF"}->{"F00821"};
	my %hs_temp;
	
	unless ( $main::offline_dir )
	{
		#query
		$sql = "
				select mzmni,mzseln,mzmska,mzmskd,mzmskj,mzmskk,mzmskf,mzjtoe
				from $table.f00821
				where mzmni in ('ZHIDDEN','ZHIDDEN002','ZHIDDEN003')
			   ";
		$sth = $dbh->prepare($sql);
		$sth->execute;

		while (my($menu,$sel,$a,$d,$j,$k,$f,$job) = $sth->fetchrow)
		{
			$menu = IAD::MiscFunc::trim($menu);
			$sel  = IAD::MiscFunc::trim($sel);
			$a    = IAD::MiscFunc::trim($a);
			$d    = IAD::MiscFunc::trim($d);
			$j    = IAD::MiscFunc::trim($j);
			$k    = IAD::MiscFunc::trim($k);
			$f    = IAD::MiscFunc::trim($f);
			$job  = IAD::MiscFunc::trim($job);

			if ($job eq "SELECT27" || $job eq "SELECT29")
			{
				#can access jumps with this
				$hs_temp{$job}->{$menu}->{$sel}->{a} = $a;
				$hs_temp{$job}->{$menu}->{$sel}->{d} = $d;
				$hs_temp{$job}->{$menu}->{$sel}->{j} = $j;
				$hs_temp{$job}->{$menu}->{$sel}->{k} = $k;
				$hs_temp{$job}->{$menu}->{$sel}->{f} = $f;
			}
		}
		
		#at this point we have all data for 27 and 29 jumps, loop over user profiles
		#in %id and store which users can access these jumps
		open HS, ">$datad\\hs.csv"
			or die "can't open the hs.csv data file: $!\n";
		my $job_save; #what to save in the %hs hash for a job
		for my $u (keys %id)
		{
			my $ua = $id{$u}->{a};
			my $ud = $id{$u}->{d};
			my $uj = $id{$u}->{j};
			my $uk = $id{$u}->{k};
			my $uf = $id{$u}->{f};
			
			for my $job (keys %hs_temp)
			{
				if ($job eq "SELECT27")
				{
					$job_save = 27;
				}
				elsif ($job eq "SELECT29")
				{
					$job_save = 29;				
				}
				
				for my $menu ( keys %{ $hs_temp{$job} } )
				{
					for my $sel ( keys %{ $hs_temp{$job}->{$menu} } )
					{
						my $ma = $hs_temp{$job}->{$menu}->{$sel}->{a};
						my $md = $hs_temp{$job}->{$menu}->{$sel}->{d};
						my $mj = $hs_temp{$job}->{$menu}->{$sel}->{j};
						my $mk = $hs_temp{$job}->{$menu}->{$sel}->{k};
						my $mf = $hs_temp{$job}->{$menu}->{$sel}->{f};
												
						#get user indexes
						my $uai = index($user_ranking_values,$ua);
						my $udi = index($user_ranking_values,$ud);
						my $uji = index($user_ranking_values,$uj);
						my $uki = index($user_ranking_values,$uk);
						my $ufi = index($user_ranking_values,$uf);

						#get menu selection indexes
						my $mai = index($ranking_values,$ma);
						my $mdi = index($ranking_values,$md);
						my $mji = index($ranking_values,$mj);
						my $mki = index($ranking_values,$mk);
						my $mfi = index($ranking_values,$mf);

						if ( $ol{$menu} )
						{
							#menu exists in f0082
							#get overall menu locks and indexes
							my $oma = $ol{$menu}->{a};
							my $omd = $ol{$menu}->{d};
							my $omj = $ol{$menu}->{j};
							my $omk = $ol{$menu}->{k};
							my $omf = $ol{$menu}->{f};

							$oma_ind = index($ranking_values,$oma);
							$omj_ind = index($ranking_values,$omj);
							$omk_ind = index($ranking_values,$omk);
							$omd_ind = index($ranking_values,$omd);
							$omf_ind = index($ranking_values,$omf);
						}
						else
						{
							#menu does not exist...so give it no security
							$oma_ind = 0;
							$omj_ind = 0;
							$omk_ind = 0;
							$omd_ind = 0;
							$omf_ind = 0;
						} #end menu's existence check

						#first check the overall menu option locks
						if (
						        ($uai >= $oma_ind)
						     && ( ($uji == $omj_ind) || ($omj_ind == 0) || $uji == 37 )
						     &&   ($uki >= $omk_ind)
						     && ( ($udi == $omd_ind) || ($omd_ind == 0) || $udi == 37 )
						     && ( ($ufi == $omf_ind) || ($omf_ind == 0) || $ufi == 37 )
						   )
						{
							#passed overall menu option locks test - now test the menu selection lock
							if (
						           ($uai >= $mai)
								&& ( ($uji == $mji) || ($mji == 0) || $uji == 37 )
								&&   ($uki >= $mki)
								&& ( ($udi == $mdi) || ($mdi == 0) || $udi == 37 )
								&& ( ($ufi == $mfi) || ($mfi == 0) || $ufi == 37 )
						       )
							{
								#passed		
								$hs{$u}->{$job_save} = 1;

								print HS "$u|$job_save|1\n";
							}
						}
					}
				}
			}
		}
		
		close HS;
		$sth->finish;
	}
	else
	{
		#offline proccessing
		open HS, "$main::offline_dir\\data\\hs.csv"
			or die "Can't open the hs.csv file ($main::offline_dir\\data\\hs.csv): $!\n";
		while (<HS>)
		{
			chomp;
			my($u,$job,$val) = split/\|/;
			
			$hs{$u}->{$job} = $val;
		}
		close HS;
	}
	
	return \%hs;
}

#===================================
#Function Key Security - F9611 and F9612
#===================================
sub get_fk
{
	#get function key data
	my $secT92 = $JDEwConf::conf{$dsn}->{"CF"}->{"F0092"};
	my $secT93 = $JDEwConf::conf{$dsn}->{"CF"}->{"F0093"}; 
	my $comT11 = $JDEwConf::conf{$dsn}->{"CF"}->{"F9611"};
	my $comT12 = $JDEwConf::conf{$dsn}->{"CF"}->{"F9612"};
	my %fk_temp;
 
	unless ( $main::offline_dir )
	{
		#query
		$sql = "
				select fkuser,fkvscr,fkfldn,xxcmd,xxdscr,fkusal
				from $comT11.f9611,$comT12.f9612
				where fkvscr = xxvscr
				order by fkuser
			   ";
		$sth = $dbh->prepare($sql);
		$sth->execute;

		while (my($id,$scr,$fld,$fkey,$desc,$allow) = $sth->fetchrow)
		{
			$id    = IAD::MiscFunc::trim($id);
			$scr   = IAD::MiscFunc::trim($scr);
			$fld   = IAD::MiscFunc::trim($fld);
			$fkey  = IAD::MiscFunc::trim($fkey);
			$desc  = IAD::MiscFunc::trim($desc);
			$allow = IAD::MiscFunc::trim($allow);
			$scr =~ s/^V/J/;
						
			#store in temp hash
			$fk_temp{$scr}->{$fkey}->{$id}->{field} = $fld;
			$fk_temp{$scr}->{$fkey}->{$id}->{desc}  = $desc;
			$fk_temp{$scr}->{$fkey}->{$id}->{allow} = $allow;
		}
		
		#process each level in ID,Group,PUBLIC heirarchy and store real details by user ID
		for my $u (keys %id)
		{
			my $group = $id{$u}->{gp};
			
			for my $job ( keys %fk_temp )
			{
				for my $fkey ( keys %{ $fk_temp{$job} } )
				{
					if ( exists $fk_temp{$job}->{$fkey}->{$u} )
					{
						#user id level exists
						$fk{$u}->{$job}->{$fkey}->{desc}  = $fk_temp{$job}->{$fkey}->{$u}->{desc};
						$fk{$u}->{$job}->{$fkey}->{allow} = $fk_temp{$job}->{$fkey}->{$u}->{allow};
					}
					elsif ( exists $fk_temp{$job}->{$fkey}->{$group} )
					{
						#group level exists
						$fk{$u}->{$job}->{$fkey}->{desc}  = $fk_temp{$job}->{$fkey}->{$group}->{desc};
						$fk{$u}->{$job}->{$fkey}->{allow} = $fk_temp{$job}->{$fkey}->{$group}->{allow};
					}
					elsif ( exists $fk_temp{$job}->{$fkey}->{$pub} )
					{
						#*public level exists
						$fk{$u}->{$job}->{$fkey}->{desc}  = $fk_temp{$job}->{$fkey}->{$pub}->{desc};
						$fk{$u}->{$job}->{$fkey}->{allow} = $fk_temp{$job}->{$fkey}->{$pub}->{allow};
					}
				} # fld for()
			} # job for()
		} #id for()
		
		open FK, ">$datad\\fk.csv"
			or die "Can't open the fk.csv file: $!\n";		
		for my $u (sort keys %fk)
		{
			for my $job ( sort keys %{ $fk{$u} } )
			{
				for my $fkey (sort keys %{ $fk{$u}->{$job} } )
				{
					print FK "$u|$job|$fkey|$fk{$u}->{$job}->{$fkey}->{desc}|$fk{$u}->{$job}->{$fkey}->{allow}\n";
				}
			}
		}
		close FK;
	}
	else	
	{
		#offline processing	
		open FK, "$main::offline_dir\\data\\fk.csv"
			or die "Can't open the fk.csv file ($main::offline_dir\\data\\fk.csv): $!\n";
		while (<FK>)
		{
			chomp;
			my($id,$scr,$fkey,$desc,$allow) = split/\|/;			
			$id    = IAD::MiscFunc::trim($id);
			$scr   = IAD::MiscFunc::trim($scr);
			$fkey  = IAD::MiscFunc::trim($fkey);			
			$desc  = IAD::MiscFunc::trim($desc);
			$allow = IAD::MiscFunc::trim($allow);			
			$scr =~ s/^V/J/;
			
			#store
			$fk{$id}->{$scr}->{$fkey}->{desc}  = $desc;
			$fk{$id}->{$scr}->{$fkey}->{allow} = $allow;	
		}
		close FK;
	}

	return \%fk;
}

#==========================
#Search Type Security - F0005
#==========================
sub get_st
{
	my $table = $JDEwConf::conf{$dsn}->{"CF"}->{"F0005"};
	my %temp_st;
	my %temp_desc;
	
	unless ( $main::offline_dir )
	{
		#create the query
		$sql = "
				  select drky,drrt,drdl01
				  from $table.f0005
				  where drsy = '94'
				  order by drky
				";
		$sth = $dbh->prepare($sql);
		$sth->execute;

		while (my($u_or_g,$doc_type,$desc) = $sth->fetchrow)
		{
			#trim
			$u_or_g   = IAD::MiscFunc::trim($u_or_g);
			$doc_type = IAD::MiscFunc::trim($doc_type);
			$desc     = IAD::MiscFunc::trim($desc);
			
			#the description here isn't actually the description, but instead holds  the add, change, or delete info ...thus parse this information, we'll get the description next
			my $add = "";
			my $change = "";
			my $delete = "";

			#add check -logic behind match pattern: pretty self-explanatory, so I'm  writing this to say I'm not going to explain it
			if ( $desc =~ /AC|A\s+|ACD/ )
			{
				$add = 'Y';
			}
			else
			{
				$add = 'N';
			}

			#change check - logic behind match pattern: AC, CD and ACD are pretty self-explanatory s all would evidence change capabilities.  the \s+\s+C pattern is
			#used to get the case where they have ONLY change capabilities.  use 2 space characters instead of just one to prevent matches against patterns like 
			#'Military Customer' which is just a space between the description...not change capabilities.  a pattern of just \s+C would come up with a match here of 'Military< C>ustomer' which would be
			#incorrect
			if ( $desc =~ /AC|(\s+\s+C)|CD|ACD/ )
			{
				$change = 'Y';
			}
			else
			{
				$change = 'N';
			}

			#delete check - logic behind match pattern: CD and ACD are pretty self-explanatory as both would evidence delete capabilities.  the \s+\s+D pattern is used to 
			#get the case where they have ONLY delete capabilities.  use 2 space characters instead of just one to prevent matches against patterns like 'David D'Arizo' 
			#which is just a space between a person's name.  if a pattern of \s+D was used, a match would come up in this case of 'David< D>'Arizo' which would be incorrect.
			if ( $desc =~ /CD|\s+\s+D|ACD/ )
			{
				$delete = 'Y';
			}
			else
			{
				$delete = 'N';
			}	

			#temporarily store data
			$temp_st{$doc_type}->{$u_or_g}->{add}    = $add;
			$temp_st{$doc_type}->{$u_or_g}->{change} = $change;
			$temp_st{$doc_type}->{$u_or_g}->{delete} = $delete;
		}
		$sth->finish;
		
		#create the second query - to get desc
		$sql = "
				select drky,drdl01
				from $table.f0005
				where drsy = '01'
				and drrt = 'ST'
				order by drky
			   ";
		$sth = $dbh->prepare($sql);
		$sth->execute;
		
		while (my($doc_type,$real_desc) = $sth->fetchrow)
		{
			$doc_type  = IAD::MiscFunc::trim($doc_type);
			$real_desc = IAD::MiscFunc::trim($real_desc);
			
			$temp_desc{$doc_type}->{desc} = $real_desc;
		}
		$sth->finish;
		
		#do hierarchy analysis	
		for my $u (keys %id)
		{
			my $group = $id{$u}->{gp};
		
			for my $doc_type (keys %temp_st)
			{
				if ( exists $temp_st{$doc_type}->{$u} )
				{
					#user id level exists
					$st{$u}->{$doc_type}->{add}    = $temp_st{$doc_type}->{$u}->{add};
					$st{$u}->{$doc_type}->{change} = $temp_st{$doc_type}->{$u}->{change};
					$st{$u}->{$doc_type}->{delete} = $temp_st{$doc_type}->{$u}->{delete};
					$st{$u}->{$doc_type}->{desc}   = $temp_desc{$doc_type}->{desc};
					
				}
				elsif ( exists $temp_st{$doc_type}->{$group} )
				{
					#group level exists
					$st{$u}->{$doc_type}->{add}    = $temp_st{$doc_type}->{$group}->{add};
					$st{$u}->{$doc_type}->{change} = $temp_st{$doc_type}->{$group}->{change};
					$st{$u}->{$doc_type}->{delete} = $temp_st{$doc_type}->{$group}->{delete};
					$st{$u}->{$doc_type}->{desc}   = $temp_desc{$doc_type}->{desc};					
				}
				elsif ( exists $temp_st{$doc_type}->{$pub} )
				{
					#*public level exists
					$st{$u}->{$doc_type}->{add}    = $temp_st{$doc_type}->{$pub}->{add};
					$st{$u}->{$doc_type}->{change} = $temp_st{$doc_type}->{$pub}->{change};
					$st{$u}->{$doc_type}->{delete} = $temp_st{$doc_type}->{$pub}->{delete};					
					$st{$u}->{$doc_type}->{desc}   = $temp_desc{$doc_type}->{desc};
				}
			} #doc_type for()
		} #u for()
		
		#save to file
		open ST, ">$datad\\st.csv"
			or die "Can't open the st.csv file: $!\n";
		
		for my $u (sort keys %st)
		{
			for my $doc_type ( sort keys %{ $st{$u} } )
			{
				my $add    = $st{$u}->{$doc_type}->{add};
				my $change = $st{$u}->{$doc_type}->{change};
				my $delete = $st{$u}->{$doc_type}->{delete};
				my $desc   = $temp_desc{$doc_type}->{desc};
				
				#print
				print ST "$u|$doc_type|$desc|$add|$change|$delete\n";	
			}
		}	
		close ST;
		
		#free memory
		%temp_st   = ();		
		%temp_desc = ();

	}
	else
	{
		#offline processing
		open ST, "$main::offline_dir\\data\\st.csv"
	        or die "can't open the st.csv file: $!\n";
		while (<ST>)
		{
			chomp;
			my($u,$doc_type,$desc,$add,$change,$delete) = split/\|/;
			$u        = IAD::MiscFunc::trim($u);
			$doc_type = IAD::MiscFunc::trim($doc_type);
			$desc     = IAD::MiscFunc::trim($desc);
			$add      = IAD::MiscFunc::trim($add);
			$change   = IAD::MiscFunc::trim($change);
			$delete   = IAD::MiscFunc::trim($delete);
			
			#store			
			$st{$u}->{$doc_type}->{add}    = $add;			
			$st{$u}->{$doc_type}->{change} = $change;			
			$st{$u}->{$doc_type}->{delete} = $delete;				
			$st{$u}->{$doc_type}->{desc}   = $desc;			
		}
		close ST;
	}
	
	#note, no return value here, this function can only be called from within the get_ac() function if we're process
	#the corporate HQ system which is the 'jdesec' DSN.
}

#==========================
#Action Code Security - F0003
#==========================
sub get_ac
{
	my $table = $JDEwConf::conf{$dsn}->{"CF"}->{"F0003"};
	my %ac_temp;
	
	unless ( $main::offline_dir )
	{
		$sql = "select asuser,aspid,asa,aschng,asdlt
				from $table.f0003
				order by asuser
			   ";
		$sth = $dbh->prepare($sql);
		$sth->execute;
		
		while (my($uid,$pid,$add,$change,$delete) = $sth->fetchrow)
		{
			$uid    = IAD::MiscFunc::trim($uid);
			$pid    = IAD::MiscFunc::trim($pid);
			$pid    =~ s/^P/J/;
			$add    = IAD::MiscFunc::trim($add);
			$change = IAD::MiscFunc::trim($change);
			$delete = IAD::MiscFunc::trim($delete);
			
			#store
			$ac_temp{$pid}->{$uid}->{add}    = $add;
			$ac_temp{$pid}->{$uid}->{change} = $change;
			$ac_temp{$pid}->{$uid}->{delete} = $delete;		
		}
		$sth->finish;
		
		#do levels hierarchy analysis
		for my $u (keys %id)
		{
			my $group = $id{$u}->{gp};
		
			for my $job (keys %ac_temp)
			{
				if ( exists $ac_temp{$job}->{$u} )
				{
					#user id level exists
					$ac{$u}->{$job}->{add}    = $ac_temp{$job}->{$u}->{add};
					$ac{$u}->{$job}->{change} = $ac_temp{$job}->{$u}->{change};
					$ac{$u}->{$job}->{delete} = $ac_temp{$job}->{$u}->{delete};
				}
				elsif ( exists $ac_temp{$job}->{$group} )
				{
					#group level exists
					$ac{$u}->{$job}->{add}    = $ac_temp{$job}->{$group}->{add};
					$ac{$u}->{$job}->{change} = $ac_temp{$job}->{$group}->{change};
					$ac{$u}->{$job}->{delete} = $ac_temp{$job}->{$group}->{delete};
				}
				elsif ( exists $ac_temp{$job}->{$pub} )
				{
					#*public level exists
					$ac{$u}->{$job}->{add}    = $ac_temp{$job}->{$pub}->{add};
					$ac{$u}->{$job}->{change} = $ac_temp{$job}->{$pub}->{change};
					$ac{$u}->{$job}->{delete} = $ac_temp{$job}->{$pub}->{delete};					
				}
			} #job for()
		} #id for()
		
		#print to data file
		open AC, ">$datad\\ac.csv"
			or die "Can't open the ac.csv file: $!\n";
		for my $u (sort keys %ac)
		{
			for my $job (sort keys %{ $ac{$u} } )
			{
				print AC "$u|$job|$ac{$u}->{$job}->{add}|$ac{$u}->{$job}->{change}|$ac{$u}->{$job}->{delete}\n";
			}
		}
		close AC;
	}
	else
	{
		#offline processing
		open AC, "$main::offline_dir\\data\\ac.csv"
	        or die "can't open the ac.csv file: $!\n";
		while (<AC>)
		{
			chomp;
			my($id,$pid,$add,$change,$delete) = split/\|/;
			$id     = IAD::MiscFunc::trim($id);
			$pid    = IAD::MiscFunc::trim($pid);
			$pid    =~ s/^P/J/;
			$add    = IAD::MiscFunc::trim($add);
			$change = IAD::MiscFunc::trim($change);
			$delete = IAD::MiscFunc::trim($delete);
			
			#store
			$ac{$id}->{$pid}->{add}    = $add;			
			$ac{$id}->{$pid}->{change} = $change;			
			$ac{$id}->{$pid}->{delete} = $delete;			
		}
		close AC;
	}

	#do special processing if the DSN is jdesec - UST corp uses search type security so take this into account for any programs that implement search type security
	if ( lc($main::dsn) eq "jdesec" )
	{
		#doing analysis on corporate HQ, must process search type security, so first obtain search type details in the %st hash		
		get_st();
		
		#next do action code analysis against search type details
		for my $u (keys %ac)
		{			
			for my $pid ( keys %{ $ac{$u} } )
			{		
				#search type security program?
				unless ( $JDEwConf::conf{ $main::dsn }->{CP}->{$pid} eq "st" ) { next; }
				
				my $pid_add = $ac{$u}->{$pid}->{add};
				my $pid_chg = $ac{$u}->{$pid}->{change};
				my $pid_dlt = $ac{$u}->{$pid}->{delete};
				
				for my $doc_type ( keys %{ $st{$u} } )
				{
					my $dt_add  = $st{$u}->{$doc_type}->{add};
					my $dt_chg  = $st{$u}->{$doc_type}->{change};
					my $dt_dlt  = $st{$u}->{$doc_type}->{delete};
					my $dt_desc = $st{$u}->{$doc_type}->{desc};
					
					#do program and search type analysis to get true action code - add in an ST branch to the %ac hash to hold this detail
					#add					
					if ( lc($pid_add) eq 'y' && lc($dt_add) eq 'y' )
					{
						
						$ac{$u}->{$pid}->{ST}->{$doc_type}->{add}  = 'Y';
						$ac{$u}->{$pid}->{ST}->{$doc_type}->{desc} = $dt_desc;
					}
					else
					{
						$ac{$u}->{$pid}->{ST}->{$doc_type}->{add}  = 'N';
						$ac{$u}->{$pid}->{ST}->{$doc_type}->{desc} = $dt_desc;
					}
		
					#change
					if ( lc($pid_chg) eq 'y' && lc($dt_chg) eq 'y' )
					{
						$ac{$u}->{$pid}->{ST}->{$doc_type}->{change} = 'Y';
						$ac{$u}->{$pid}->{ST}->{$doc_type}->{desc}   = $dt_desc;
					}
					else
					{
						$ac{$u}->{$pid}->{ST}->{$doc_type}->{change} = 'N';
						$ac{$u}->{$pid}->{ST}->{$doc_type}->{desc}   = $dt_desc;
					}
					
					#delete
					if ( lc($pid_dlt) eq 'y' && lc($dt_dlt) eq 'y' )
					{
						$ac{$u}->{$pid}->{ST}->{$doc_type}->{delete} = 'Y';
						$ac{$u}->{$pid}->{ST}->{$doc_type}->{desc}   = $dt_desc;
					}
					else
					{
						$ac{$u}->{$pid}->{ST}->{$doc_type}->{delete} = 'N';
						$ac{$u}->{$pid}->{ST}->{$doc_type}->{desc}   = $dt_desc;
					}
				} #doc_type for()
			} #pid for()
		} #u for()
	
		#after it's all over, free %st memory
		%st = ();
		
	} #jdesec dsn if()
	
	return \%ac;
}

#==========================
# Program Descriptions - F9801
#==========================
sub get_pd
{
	my $table = $JDEwConf::conf{$dsn}->{"CF"}->{"F9801"};
	
	unless ( $main::offline_dir )
	{
		$sql = "
				select simid,simd
				from $table.f9801
				order by simid
			   ";
		$sth = $dbh->prepare($sql);
		$sth->execute;
		
		open PD, ">$datad\\f9801.csv"
			or die "Can't open the f9801.csv file: $!\n";
			
		while (my($prog,$desc) = $sth->fetchrow)
		{
			$prog = IAD::MiscFunc::trim($prog);
			$desc = IAD::MiscFunc::trim($desc);
			$pd{$prog}->{desc} = $desc;
			
			print PD "$prog|$desc\n";
		}
		
		close PD;
		$sth->finish;
	}
	else
	{
		#offline processing
		open PD, "$main::offline_dir\\data\\f9801.csv"
	        or die "can't open the f9801.csv file: $!\n";
		while (<PD>)
		{
			chomp;
			my($prog,$desc) = split/\|/;
			$prog = IAD::MiscFunc::trim($prog);
			$desc = IAD::MiscFunc::trim($desc);
						
			#store
			$pd{$prog}->{desc} = $desc;			
		}
		close PD;
	}

	return \%pd;
}

#============
# AUDUSRPRF 
#============
sub get_ui
{
	unless ( $main::offline_dir )
	{
		#first try to delete the current users_info file on the 400
		$sql = "call qcmdexc('dltf file(audtlib/users_info)',0000000029.00000)";
		$sth = $dbh->prepare($sql);
		$sth->execute or warn "audtlib/users_info unsuccessfully deleted, probably didn't exist...\n";
		
		#now create the users_info file
		$sql = "call qcmdexc('audusrprf users_info',0000000020.00000)";
		$sth = $dbh->prepare($sql);
		$sth->execute or warn "cound't execute audusrprf...\n";
		

		#open file to write data to
		open UINFO, ">$datad\\users_info.csv"
	        or die "can't open the users_info.csv file: $!\n";

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
			
			$ui{$upuprf}->{name}   = $uptext;
			$ui{$upuprf}->{group}  = $upgrpf;
			$ui{$upuprf}->{status} = $upstat;
			print UINFO "$upuprf|$uptext|$upgrpf|$upstat\n";
		}

		close UINFO;
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
	
	return \%ui;
}























#===============================
#Function to Store User's Menu Tree
#===============================
sub st0r3M3
{
 my($self,$t,$u) = @_;
 store($t,"$mtd\\${ $u }.mt");
}

#=======
#Return 1
#=======
1; 