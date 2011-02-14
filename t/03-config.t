#!perl
use strict ;

use Data::Dumper ;

use Test::More tests => 3;

## Check module loads ok
use Linux::DVB::DVBT::Advert qw/:all/ ;
#use Linux::DVB::DVBT::Advert::Config ;
#use Linux::DVB::DVBT::Advert::Constants ;

my %expected_def = (
          $Linux::DVB::DVBT::Advert::Config::ADVERT_GLOBAL_SECTION => {}
) ;


my %expected_full = (
          $Linux::DVB::DVBT::Advert::Config::ADVERT_GLOBAL_SECTION => {
                                                          'max_gap' => 11,
                                                          'start_pad' => 3005,
                                                          'frame' => {
                                                                       'max_gap' => 12,
                                                                       'schange_jump' => 31,
                                                                       'schange_cutlevel' => 86,
                                                                       'min_frames' => 4,
                                                                       'min_advert' => 4504,
                                                                       'max_advert' => 4506,
                                                                       'max_black' => 49,
                                                                       'max_brightness' => 61,
                                                                       'brightness_jump' => 201,
                                                                       'min_program' => 7504,
                                                                       'window_percent' => 96,
                                                                       'test_brightness' => 41,
                                                                       'noise_level' => 6,
                                                                       'frame_window' => 6
                                                                     },
                                                          'min_frames' => 3,
                                                          'end_pad' => 3003,
                                                          'audio' => {
                                                                       'min_advert' => 3030,
                                                                       'max_advert' => 6030,
                                                                       'max_gap' => 270,
                                                                       'min_program' => 7530,
                                                                       'frame_window' => 6020,
                                                                       'silence_window' => 130,
                                                                       'min_frames' => 8
                                                                     },
                                                          'logo' => {
                                                                      'max_gap' => 260,
                                                                      'logo_skip_frames' => 27,
                                                                      'logo_fall_threshold' => 52,
                                                                      'logo_rise_threshold' => 82,
                                                                      'logo_edge_threshold' => 7,
                                                                      'logo_ave_points' => 252,
                                                                      'logo_checking_period' => 30002,
                                                                      'min_program' => 7510,
                                                                      'logo_num_checks' => 7,
                                                                      'logo_ok_percent' => 82,
                                                                      'logo_edge_radius' => 4,
                                                                      'logo_edge_step' => 2,
                                                                      'logo_max_percentage_of_screen' => 12,
                                                                      'min_frames' => 35,
                                                                      'max_advert' => 4510,
                                                                      'min_advert' => 4510,
                                                                      'window_percent' => 97,
                                                                      'frame_window' => 30
                                                                    },
                                                          'reduce_min_gap' => 1505,
                                                          'detection_method' => 7,
                                                          'max_advert' => 4505,
                                                          'min_advert' => 4503,
                                                          'reduce_end' => 0,
                                                          'min_program' => 7505,
                                                          'frame_window' => 5
                                                        }
) ;

## Check config read
my $ad_config_href ;

print Data::Dumper->Dump(['Def Search', $Linux::DVB::DVBT::Advert::CONFIG_DIR]) ;

$ad_config_href = ad_config(['.']) ;
print Data::Dumper->Dump(['.', $ad_config_href]) ;
is_deeply($ad_config_href, \%expected_def) ;

Linux::DVB::DVBT::Advert::ad_config_search( ['./t/cfg-full'] ) ;
$ad_config_href = ad_config() ;
print Data::Dumper->Dump(['./t/cfg-full', $ad_config_href]) ;

is_deeply($ad_config_href, \%expected_full) ;


my %expected_chan = (
	%{ $expected_full{$Linux::DVB::DVBT::Advert::Config::ADVERT_GLOBAL_SECTION} },
	'total_black_frames' => 0,
	'total_scene_frames' => 0,
	'total_logo_frames' => 0,
	'total_size_frames' => 0,
	'num_frames' => 1,
	'audio_pid' => -1,
	'pid' => -1,

	# not used
	'increase_start' => 0,
	'increase_min_gap' => 1500,
	) ;
	
$expected_chan{'frame'}{'remove_logo'} = 0 ;
$expected_chan{'audio'}{'silence_threshold'} = -80 ;
$expected_chan{'audio'}{'scale'} = 1 ;
$expected_chan{'logo'}{'logo_window'} = 50 ;

my $chan_href = channel_settings({}, 'Dave', $ad_config_href) ;
print Data::Dumper->Dump(['Chan settings', $chan_href]) ;
is_deeply($chan_href, \%expected_chan) ;


