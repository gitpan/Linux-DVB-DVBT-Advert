// VERSION = "1.002"
//
// Standard C code loaded outside XS space. Contains useful routines used by advert detection functions
#include "ts_advert.h"
#include "ts_cut.h"
#include "ts_split.h"

//---------------------------------------------------------------------------------------------------------
// HOOKS
//---------------------------------------------------------------------------------------------------------


//---------------------------------------------------------------------------------------------------------
static void advert_progress_hook(enum TS_progress_state state, unsigned progress, unsigned total, void *user_data)
{
	dSP ;
struct Ad_user_data  *hook_data = (struct Ad_user_data *)user_data ;
char *state_str ;
char ad_state_str[256] ;

	ENTER;
	SAVETMPS;

	if (hook_data->progress_callback)
	{
		switch (state)
		{
			case PROGRESS_START 	: state_str = "START"; break ;
			case PROGRESS_RUNNING 	: state_str = "RUNNING"; break ;
			case PROGRESS_END 		: state_str = "END"; break ;
			case PROGRESS_STOPPED 	: state_str = "STOPPED"; break ;
			default				 	: state_str = "UNKNOWN"; break ;
		}

		if (hook_data->process_state == ADVERT_PREPROCESS)
		{
			sprintf(ad_state_str, "PREPROCESS %s", state_str) ;
		}
		else
		{
			sprintf(ad_state_str, "PROCESS %s", state_str) ;
		}

		PUSHMARK(SP);
		XPUSHs(sv_2mortal( newSVpv( (char *)ad_state_str, strlen(ad_state_str) ) ));
		XPUSHs(sv_2mortal( newSViv(progress) ));
		XPUSHs(sv_2mortal( newSViv(total) ));
		XPUSHs((SV *)hook_data->extra_data);
		PUTBACK;

		call_sv(hook_data->progress_callback, G_DISCARD);

		SPAGAIN;
	}

	FREETMPS;
	LEAVE;

}


//========================================================================================================
// FUNCTIONS
//========================================================================================================

//---------------------------------------------------------------------------------------------------------
// Copy any user settings from the Perl HASH into the user_data
//
static void advert_set_settings(struct Ad_user_data *user_data, HV *settings_href)
{
SV **val;

	if (settings_href)
	{
		/*
		//-- user settings --
		unsigned debug ;

		// Pid to use
		int	pid ;

		// how to detect
		unsigned detection_method ;

		//-- Settings for detection methods --
		struct Ad_frame_settings	frame_settings ;
		struct Ad_logo_settings		logo_settings ;
		struct Ad_audio_settings	audio_settings ;
		*/
		HVF_IV(settings_href, debug, user_data->debug) ;
		HVF_IV(settings_href, dbg-ts, user_data->ts_debug) ;
		HVF_IV(settings_href, pid, user_data->pid) ;
		HVF_IV(settings_href, detection_method, user_data->detection_method) ;

		HVF_SVV(settings_href, progress_callback, user_data->progress_callback) ;
		HVF_SVV(settings_href, user_data, user_data->extra_data) ;

		/*
		//-- frame settings --
		unsigned debug ;

		// maximum pixel value considered as a black frame
		unsigned max_black ;

		// percentage of picture to analyse
		unsigned window_percent ;

		unsigned max_brightness;				// frame not black if any pixels checked are greater than this (scale 0 to 255)
		unsigned test_brightness;				// frame not pure black if any pixels are greater than this, will check average

		unsigned brightness_jump;
		unsigned schange_cutlevel;
		unsigned schange_jump;

		unsigned noise_level;
		*/
		HVF_IV(settings_href, dbg-frame, user_data->frame_settings.debug) ;
		HVF_IV(settings_href, max_black, user_data->frame_settings.max_black) ;
		HVF_IV(settings_href, window_percent, user_data->frame_settings.window_percent) ;
		HVF_IV(settings_href, max_brightness, user_data->frame_settings.max_brightness) ;
		HVF_IV(settings_href, test_brightness, user_data->frame_settings.test_brightness) ;
		HVF_IV(settings_href, brightness_jump, user_data->frame_settings.brightness_jump) ;
		HVF_IV(settings_href, schange_cutlevel, user_data->frame_settings.schange_cutlevel) ;
		HVF_IV(settings_href, schange_jump, user_data->frame_settings.schange_jump) ;
		HVF_IV(settings_href, noise_level, user_data->frame_settings.noise_level) ;
		HVF_IV(settings_href, remove_logo, user_data->frame_settings.remove_logo) ;

		/*
		//-- logo settings --
		unsigned debug ;

		// percentage of picture to analyse
		unsigned window_percent ;


		// rolling "window" of time used for logo detection. Specified as a number of frames
		unsigned logo_window ;

		unsigned logo_edge_radius ;
		unsigned logo_edge_step ;
		unsigned logo_edge_threshold ;

		// max time to check for logo (in frames)
		unsigned logo_checking_period ;
		unsigned logo_skip_frames ;
		unsigned logo_num_checks ;
		unsigned logo_ok_percent ;
		unsigned logo_max_percentage_of_screen ;
		unsigned logo_ave_points ;
		*/
		HVF_IV(settings_href, dbg-logo, user_data->logo_settings.debug) ;
		HVF_IV(settings_href, window_percent, user_data->logo_settings.window_percent) ;
		HVF_IV(settings_href, logo_window, user_data->logo_settings.logo_window) ;
		HVF_IV(settings_href, logo_edge_radius, user_data->logo_settings.logo_edge_radius) ;
		HVF_IV(settings_href, logo_edge_step, user_data->logo_settings.logo_edge_step) ;
		HVF_IV(settings_href, logo_edge_threshold, user_data->logo_settings.logo_edge_threshold) ;
		HVF_IV(settings_href, logo_checking_period, user_data->logo_settings.logo_checking_period) ;
		HVF_IV(settings_href, logo_skip_frames, user_data->logo_settings.logo_skip_frames) ;
		HVF_IV(settings_href, logo_num_checks, user_data->logo_settings.logo_num_checks) ;
		HVF_IV(settings_href, logo_ok_percent, user_data->logo_settings.logo_ok_percent) ;
		HVF_IV(settings_href, logo_max_percentage_of_screen, user_data->logo_settings.logo_max_percentage_of_screen) ;
		HVF_IV(settings_href, logo_ave_points, user_data->logo_settings.logo_ave_points) ;

		/* audio settings */
		HVF_IV(settings_href, dbg-audio, user_data->audio_settings.debug) ;
		HVF_IV(settings_href, scale, user_data->audio_settings.scale) ;
		HVF_IV(settings_href, silence_threshold, user_data->audio_settings.silence_threshold) ;
	}
}





//---------------------------------------------------------------------------------------------------------
// Copy all settings from the user_data struct into the Perl HASH
//
static void advert_get_settings(struct Ad_user_data *user_data, HV *settings)
{
HV * rh;

	//== Common ===============

	//-- Used by C routines ---
	HVS_INT_SETTING(settings, pid, user_data->pid, ) ;
	HVS_INT_SETTING(settings, audio_pid, user_data->audio_pid, ) ;
	HVS_INT_SETTING(settings, detection_method, user_data->detection_method, ) ;
	HVS_INT_SETTING(settings, num_frames, user_data->last_framenum+1, ) ;

	//-- Used only by Perl modules --
	HVS_INT_SETTING(settings, max_advert, 		(3*60*FPS), ) ;
	HVS_INT_SETTING(settings, min_advert, 		(3*60*FPS), ) ;
	HVS_INT_SETTING(settings, min_program, 		(5*60*FPS), ) ;
	HVS_INT_SETTING(settings, start_pad, 		(2*60*FPS), ) ;
	HVS_INT_SETTING(settings, end_pad,	 		(2*60*FPS), ) ;
	HVS_INT_SETTING(settings, min_frames, 		2, ) ;
	HVS_INT_SETTING(settings, frame_window,		4, ) ;
	HVS_INT_SETTING(settings, max_gap,			10, ) ;
	HVS_INT_SETTING(settings, reduce_end,		0, ) ;
	HVS_INT_SETTING(settings, reduce_min_gap,	(60*FPS), ) ;
	HVS_INT_SETTING(settings, increase_start,	0, ) ;
	HVS_INT_SETTING(settings, increase_min_gap,	(60*FPS), ) ;


	//== Frame ===============

	//-- Used by C routines ---
	rh = (HV *)sv_2mortal((SV *)newHV());
	HVS_INT_SETTING(rh, max_black, user_data->frame_settings.max_black, frame.) ;
	HVS_INT_SETTING(rh, window_percent, user_data->frame_settings.window_percent, frame.) ;
	HVS_INT_SETTING(rh, max_brightness, user_data->frame_settings.max_brightness, frame.) ;
	HVS_INT_SETTING(rh, test_brightness, user_data->frame_settings.test_brightness, frame.) ;
	HVS_INT_SETTING(rh, brightness_jump, user_data->frame_settings.brightness_jump, frame.) ;
	HVS_INT_SETTING(rh, schange_cutlevel, user_data->frame_settings.schange_cutlevel, frame.) ;
	HVS_INT_SETTING(rh, schange_jump, user_data->frame_settings.schange_jump, frame.) ;
	HVS_INT_SETTING(rh, noise_level, user_data->frame_settings.noise_level, frame.) ;
	HVS_INT_SETTING(rh, remove_logo, user_data->frame_settings.remove_logo, frame.) ;

	//-- Used only by Perl modules --
	HVS_INT_SETTING(rh, max_advert, 		(3*60*FPS), frame.) ;
	HVS_INT_SETTING(rh, min_advert, 		(3*60*FPS), frame.) ;
	HVS_INT_SETTING(rh, min_program, 		(5*60*FPS), frame.) ;
//	HVS_INT_SETTING(rh, start_pad, 			(2*60*FPS), frame.) ;
//	HVS_INT_SETTING(rh, end_pad,	 		(2*60*FPS), frame.) ;
	HVS_INT_SETTING(rh, min_frames, 		2, frame.) ;
	HVS_INT_SETTING(rh, frame_window,		4, frame.) ;
	HVS_INT_SETTING(rh, max_gap,			10, frame.) ;
//	HVS_INT_SETTING(rh, reduce_end,			0, frame.) ;
//	HVS_INT_SETTING(rh, reduce_min_gap,		(60*FPS), frame.) ;

	HVS(settings, frame, newRV((SV *)rh)) ;


	//== Logo ===============

	//-- Used by C routines ---
	rh = (HV *)sv_2mortal((SV *)newHV());
	HVS_INT_SETTING(rh, window_percent, user_data->logo_settings.window_percent, logo.) ;
	HVS_INT_SETTING(rh, logo_window, user_data->logo_settings.logo_window, logo.) ;
	HVS_INT_SETTING(rh, logo_edge_radius, user_data->logo_settings.logo_edge_radius, logo.) ;
	HVS_INT_SETTING(rh, logo_edge_step, user_data->logo_settings.logo_edge_step, logo.) ;
	HVS_INT_SETTING(rh, logo_edge_threshold, user_data->logo_settings.logo_edge_threshold, logo.) ;
	HVS_INT_SETTING(rh, logo_checking_period, user_data->logo_settings.logo_checking_period, logo.) ;
	HVS_INT_SETTING(rh, logo_skip_frames, user_data->logo_settings.logo_skip_frames, logo.) ;
	HVS_INT_SETTING(rh, logo_num_checks, user_data->logo_settings.logo_num_checks, logo.) ;
	HVS_INT_SETTING(rh, logo_ok_percent, user_data->logo_settings.logo_ok_percent, logo.) ;
	HVS_INT_SETTING(rh, logo_max_percentage_of_screen, user_data->logo_settings.logo_max_percentage_of_screen, logo.) ;
	HVS_INT_SETTING(rh, logo_ave_points, user_data->logo_settings.logo_ave_points, logo.) ;

	//-- Used only by Perl modules --
	HVS_INT_SETTING(rh, max_advert, 			(3*60*FPS), logo.) ;
	HVS_INT_SETTING(rh, min_advert, 			(3*60*FPS), logo.) ;
	HVS_INT_SETTING(rh, min_program, 			(5*60*FPS), logo.) ;
//	HVS_INT_SETTING(rh, start_pad, 				(2*60*FPS), logo.) ;
//	HVS_INT_SETTING(rh, end_pad,	 			(2*60*FPS), logo.) ;
	HVS_INT_SETTING(rh, min_frames, 			FPS, logo.) ;
	HVS_INT_SETTING(rh, frame_window,			20, logo.) ;
	HVS_INT_SETTING(rh, max_gap,				(10*FPS), logo.) ;
//	HVS_INT_SETTING(rh, reduce_end,				0, logo.) ;
//	HVS_INT_SETTING(rh, reduce_min_gap,			(60*FPS), logo.) ;
	HVS_INT_SETTING(rh, logo_rise_threshold,	user_data->logo_settings.logo_ok_percent, logo.) ;
	HVS_INT_SETTING(rh, logo_fall_threshold,	50, logo.) ;

	HVS(settings, logo, newRV((SV *)rh)) ;


	//== Audio ===============

	//-- Used by C routines ---
	rh = (HV *)sv_2mortal((SV *)newHV());
	HVS_INT_SETTING(rh, scale, user_data->audio_settings.scale, audio.) ;
	HVS_INT_SETTING(rh, silence_threshold, user_data->audio_settings.silence_threshold, audio.) ;

	//-- Used only by Perl modules --
	HVS_INT_SETTING(rh, max_advert, 			(4*60*FPS), audio.) ;
	HVS_INT_SETTING(rh, min_advert, 			(2*60*FPS), audio.) ;
	HVS_INT_SETTING(rh, min_program, 			(5*60*FPS), audio.) ;
//	HVS_INT_SETTING(rh, start_pad, 				(2*60*FPS), audio.) ;
//	HVS_INT_SETTING(rh, end_pad,	 			(2*60*FPS), audio.) ;
	HVS_INT_SETTING(rh, min_frames, 			2, audio.) ;
	HVS_INT_SETTING(rh, frame_window,			(4*60*FPS), audio.) ;

	HVS_INT_SETTING(rh, max_gap,				(10*FPS), audio.) ;
//	HVS_INT_SETTING(rh, reduce_end,				0, audio.) ;
//	HVS_INT_SETTING(rh, reduce_min_gap,			(60*FPS), audio.) ;

	HVS_INT_SETTING(rh, silence_window,			100, audio.) ;

	HVS(settings, audio, newRV((SV *)rh)) ;


	//== Save Totals ===============

	//-- Used only by Perl modules --
	HVS_INT_SETTING(settings, total_logo_frames, user_data->logo_totals.num_logo_frames, ) ;
	HVS_INT_SETTING(settings, total_black_frames, user_data->frame_totals.num_black_frames, ) ;
	HVS_INT_SETTING(settings, total_scene_frames, user_data->frame_totals.num_scene_frames, ) ;
	HVS_INT_SETTING(settings, total_size_frames, user_data->frame_totals.num_size_frames, ) ;



}


//---------------------------------------------------------------------------------------------------------
static void execute_advert_detection(struct Ad_user_data * user_data, char *filename, HV *settings_href, HV *results, HV *frames, HV *settings)
{
SV **val;
HV * rh;
unsigned i ;
unsigned video_framenum ;
char key[256] ;

	// Set settings
	advert_set_settings(user_data, settings_href) ;

	// Run detection - pre-process
	user_data->process_state = ADVERT_PREPROCESS ;
	run_preprocess(user_data, filename, advert_progress_hook) ;

    // Run detection - main
	user_data->process_state = ADVERT_PROCESS ;
    run_detect(user_data, filename, advert_progress_hook) ;

    // == Pass results back to Perl ==

    // copy settings
    advert_get_settings(user_data, settings) ;

#ifdef PERLXS_DEBUG
	printf("frame,frame_end,start_pkt,end_pkt,gop_pkt,black_frame,scene_frame,size_change,screen_width,screen_height,") ;
	printf("brightness,uniform,dimCount,sceneChangePercent,") ;
	printf("logo_frame,match_percent,ave_percent,") ;
	printf("audio_framenum,volume,max_volume,sample_rate,channels,samples_per_frame,samples,") ;
	printf("framesize,silent_frame,volume_dB") ;
	printf("\n") ;
#endif

    // get frame data
	video_framenum = 0 ;
	for (i=0; i <= user_data->last_framenum; i++)
	{
		// only output if we have some results for this frame entry (create monotonically increasing frame count)
		if (user_data->results_array[i].valid_frame)
		{
			HVS_RESULT_START ;

			rh = (HV *)sv_2mortal((SV *)newHV());

			HVS_INT_RESULT(rh, frame, video_framenum) ;
			HVS_INT_RESULT(rh, frame_end, video_framenum) ;

			HVS_INT_RESULT(rh, start_pkt, user_data->results_array[i].start_pkt) ;
			HVS_INT_RESULT(rh, end_pkt, user_data->results_array[i].end_pkt) ;
			HVS_INT_RESULT(rh, gop_pkt, user_data->results_array[i].gop_pkt) ;

			/*
			unsigned	black_frame ;
			unsigned	scene_frame ;

			unsigned 	screen_width ;
			unsigned 	screen_height ;
			unsigned 	brightness ;
			unsigned 	uniform ;
			unsigned	dimCount;
			int			sceneChangePercent;
			*/
			HVS_FRAME_RESULT(rh, black_frame, i) ;
			HVS_FRAME_RESULT(rh, scene_frame, i) ;
			HVS_FRAME_RESULT(rh, size_change, i) ;
			HVS_FRAME_RESULT(rh, screen_width, i) ;
			HVS_FRAME_RESULT(rh, screen_height, i) ;
			HVS_FRAME_RESULT(rh, brightness, i) ;
			HVS_FRAME_RESULT(rh, uniform, i) ;
			HVS_FRAME_RESULT(rh, dimCount, i) ;
			HVS_FRAME_RESULT(rh, sceneChangePercent, i) ;

			/*
			unsigned	logo_frame ;	// boolean

			unsigned 	match_percent ;
			unsigned 	ave_percent ;
			*/
			HVS_LOGO_RESULT(rh, logo_frame, i) ;
			HVS_LOGO_RESULT(rh, match_percent, i) ;
			HVS_LOGO_RESULT(rh, ave_percent, i) ;

			/*
			unsigned		audio_framenum ;
			int64_t			pts ;
			unsigned		volume ;
			unsigned		max_volume ;

			unsigned 		sample_rate	;
			unsigned 		channels ;
			unsigned 		samples_per_frame ;
			unsigned 		samples ;
			unsigned 		framesize ;
			*/
			HVS_AUDIO_RESULT(rh, audio_framenum, i) ;
			/*HVS_AUDIO_RESULT(rh, pts, i) ;*/
			_store_ts(rh, "pts", user_data->results_array[i].audio_results.pts) ;
			HVS_AUDIO_RESULT(rh, volume, i) ;
			HVS_AUDIO_RESULT(rh, max_volume, i) ;
			HVS_AUDIO_RESULT(rh, sample_rate, i) ;
			HVS_AUDIO_RESULT(rh, channels, i) ;
			HVS_AUDIO_RESULT(rh, samples_per_frame, i) ;
			HVS_AUDIO_RESULT(rh, samples, i) ;
			HVS_AUDIO_RESULT(rh, framesize, i) ;
			HVS_AUDIO_RESULT(rh, silent_frame, i) ;
			HVS_AUDIO_RESULT(rh, volume_dB, i) ;


			sprintf(key, "%d", i) ;
			hv_store(frames, key, strlen(key),  newRV((SV *)rh), 0) ;

			HVS_RESULT_END ;

			++video_framenum ;
		}
	}

    // Free up structures
    free_user_data(user_data) ;

}




