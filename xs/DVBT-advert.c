 # VERSION = "1.000"

 # /*---------------------------------------------------------------------------------------------------*/
 # /* Run advert detection */

SV *
dvb_advert_detect(char *filename, HV *settings_href=NULL)
	INIT:
		HV * results;
		HV * frames ;
		HV * settings ;

		struct Ad_user_data user_data ;
		SV **val;
		HV * rh;
		unsigned i ;
		char key[256] ;

		results = (HV *)sv_2mortal((SV *)newHV());
	    frames = (HV *)sv_2mortal((SV *)newHV());
	    settings = (HV *)sv_2mortal((SV *)newHV());

	CODE:
		/* Create Perl data */
		HVS(results, frames, newRV((SV *)frames)) ;
		HVS(results, settings, newRV((SV *)settings)) ;

		dvb_error_clear() ;
		init_user_data(&user_data) ;

		execute_advert_detection(&user_data, filename, settings_href, results, frames, settings) ;

	    RETVAL = newRV((SV *)results);

	OUTPUT:
      RETVAL


# /*---------------------------------------------------------------------------------------------------*/
# /* Get advert default settings (combined with any specified settings) */

SV *
dvb_advert_def_settings(HV *settings_href=NULL)
	INIT:
		HV * results;
		HV * frames ;
		HV * settings ;

		struct Ad_user_data user_data ;
		SV **val;
		HV * rh;
		unsigned i ;
		char key[256] ;

	    settings = (HV *)sv_2mortal((SV *)newHV());

	CODE:
		dvb_error_clear() ;
		init_user_data(&user_data) ;

		// Set settings
		advert_set_settings(&user_data, settings_href) ;

	    // == Pass results back to Perl ==
	    advert_get_settings(&user_data, settings) ;

	    // Free up structures
	    free_user_data(&user_data) ;

	    RETVAL = newRV((SV *)settings);

	OUTPUT:
     RETVAL


