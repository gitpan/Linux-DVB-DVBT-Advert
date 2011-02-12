ifndef libdvb_ad_lib
libdvb_ad_lib := .
endif

CFLAGS += -I$(libdvb_ad_lib)

OBJS-libdvb_ad_lib := \
 detect/advert.o \
 detect/ad_debug.o \
 detect/ad_audio.o \
 detect/ad_frame.o \
 detect/ad_logo.o
