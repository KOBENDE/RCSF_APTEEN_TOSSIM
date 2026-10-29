COMPONENT=ApteenAppC
CFLAGS += -DTOSH_DATA_LENGTH=110 -I. -fgnu89-inline
ifdef MODE
CFLAGS += -DMODE=$(MODE)
endif
TINYOS_ROOT_DIR?=/opt/tinyos-main
include $(TINYOS_ROOT_DIR)/Makefile.include
