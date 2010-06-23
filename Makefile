#
# GLOBAL Makefile for the whole L4 tree
#

L4DIR		?= .

BUILD_DIRS    = tool pkg
install-dirs  = tool pkg
clean-dirs    = tool pkg doc
cleanall-dirs = tool pkg doc

BUILD_TOOLS	= gawk gcc g++ ld perl pkg-config

CMDS_WITHOUT_OBJDIR := checkbuild up update check_build_tools

# our default target is all::
all::

#####################
# config-tool

DROPSCONF 		= y
DROPSCONF_DEFCONFIG	?= $(L4DIR)/mk/defconfig/config.x86
#DROPSCONF_CONFIG_IN	= $(L4DIR)/mk/config.in
DROPSCONF_CONFIG	= $(OBJ_BASE)/.kconfig.auto
DROPSCONF_CONFIG_H	= $(OBJ_BASE)/include/l4/bid_config.h
DROPSCONF_CONFIG_MK	= $(OBJ_BASE)/.config.all
DROPSCONF_DONTINC_MK	= y
DROPSCONF_HELPFILE	= $(L4DIR)/mk/config.help

# separation in "dependent" (ie opts the build output depends on) and
# "independent" (ie opts the build output does not depend on) opts
CONFIG_MK_INDEPOPTS	= CONFIG_BID_GENERATE_MAPFILE \
			  CONFIG_DEPEND_VERBOSE \
			  CONFIG_VERBOSE_SWITCH \
			  CONFIG_BID_COLORED_PHASES CONFIG_HAVE_LDSO \
			  CONFIG_INT_CPP_NAME_SWITCH BID_LIBGENDEP_PATHS CONFIG_INT_CPP_.*_NAME \
			  CONFIG_INT_CXX_.*_NAME CONFIG_VERBOSE CONFIG_BID_STRIP_PROGS \
			  CONFIG_INT_LD_NAME_SWITCH CONFIG_INT_LD_.*_NAME
CONFIG_MK_REAL		= $(OBJ_BASE)/.config
CONFIG_MK_INDEP		= $(OBJ_BASE)/.config.indep


ifneq ($(filter $(CMDS_WITHOUT_OBJDIR),$(MAKECMDGOALS)),)
IGNORE_MAKECONF_INCLUDE=1
endif

ifneq ($(B)$(BUILDDIR_TO_CREATE),)
IGNORE_MAKECONF_INCLUDE=1
endif

ifeq ($(IGNORE_MAKECONF_INCLUDE),)
ifneq ($(filter help config txtconfig oldconfig,$(MAKECMDGOALS)),)
# tweek $(L4DIR)/mk/Makeconf to use the intermediate file
export BID_IGN_ROOT_CONF=y
BID_ROOT_CONF=$(DROPSCONF_CONFIG_MK)
endif

# $(L4DIR)/mk/Makeconf shouln't include Makeconf.local twice
MAKECONFLOCAL		= /dev/null
include $(L4DIR)/mk/Makeconf
export DROPS_STDDIR

# after having absfilename, we can export BID_ROOT_CONF
ifneq ($(filter config txtconfig oldconfig gconfig qconfig xconfig, $(MAKECMDGOALS)),)
export BID_ROOT_CONF=$(call absfilename,$(OBJ_BASE))/.config.all
endif
endif

#####################
# rules follow

ifneq ($(strip $(B)),)
BUILDDIR_TO_CREATE := $(B)
endif
ifneq ($(strip $(BUILDDIR_TO_CREATE)),)
all:: check_build_tools
	@echo "Creating build directory \"$(BUILDDIR_TO_CREATE)\"..."
	@if [ -e "$(BUILDDIR_TO_CREATE)" ]; then	\
		echo "Already exists, aborting.";	\
		exit 1;					\
	fi
	@mkdir -p "$(BUILDDIR_TO_CREATE)"
	@cp $(DROPSCONF_DEFCONFIG) $(BUILDDIR_TO_CREATE)/.kconfig
	@$(MAKE) B= BUILDDIR_TO_CREATE= O=$(BUILDDIR_TO_CREATE) oldconfig
	@echo "done."
else

all:: l4defs

endif



# some more dependencies
tool: $(DROPSCONF_CONFIG_MK)
pkg:  $(DROPSCONF_CONFIG_MK) tool
doc:  pkgdoc

ifneq ($(CONFIG_BID_BUILD_DOC),)
install-dirs += doc
all:: doc
endif

up update:
	$(VERBOSE)svn up -N
	$(VERBOSE)svn up mk tool/gendep tool/kconfig tool/elf-patcher doc/source conf $(wildcard tool/bin)
	$(VERBOSE)$(MAKE) -C pkg up

tool ../kernel/fiasco pkg: ../dice
	$(VERBOSE)if [ -r $@/Makefile ]; then PWD=$(PWD)/$@ $(MAKE) -C $@; fi

../dice:
	$(VERBOSE)if [ -r $@/Makefile.drops ]; then                \
	   $(MAKE) -C $@ -f Makefile.drops;                        \
	fi

doc:
	$(VERBOSE)for d in tool doc ; do \
		test ! -r $$d/Makefile || PWD=$(PWD)/$$d $(MAKE) -C $$d $@ ; done

pkgdoc:
	$(VERBOSE)test ! -r pkg/Makefile || PWD=$(PWD)/pkg $(MAKE) -C pkg doc

cont:
	$(VERBOSE)$(MAKE) -C pkg cont

.PHONY: all clean cleanall install hello pkgdoc up update
.PHONY: $(BUILD_DIRS) doc/html check_build_tools cont cleanfast

cleanall::
	$(VERBOSE)rm -f *~

clean cleanall install::
	$(VERBOSE)set -e; for i in $($@-dirs) ; do \
	  if [ -r $$i/Makefile -o -r $$i/GNUmakefile ] ; then \
		PWD=$(PWD)/$$i $(MAKE) -C $$i $@ ; fi ; done

cleanfast:
	$(VERBOSE)$(RM) -r $(OBJ_BASE)/{bin,include,pkg,doc,ext-pkg,pc,lib,l4defs.mk.inc,l4defs.sh.inc,images}


L4DEF_FILE_MK ?= $(OBJ_BASE)/l4defs.mk.inc
L4DEF_FILE_SH ?= $(OBJ_BASE)/l4defs.sh.inc

l4defs: $(L4DEF_FILE_MK) $(L4DEF_FILE_SH)

generate_l4defs_files = \
	$(VERBOSE)tmpdir=$(OBJ_BASE)/l4defs.gen.dir &&                 \
	mkdir -p $$tmpdir &&                                           \
	echo "L4DIR = $(L4DIR_ABS)"                      > $$tmpdir/Makefile && \
	echo "OBJ_BASE = $(OBJ_BASE)"                   >> $$tmpdir/Makefile && \
	echo "L4_BUILDDIR = $(OBJ_BASE)"                >> $$tmpdir/Makefile && \
	echo "SRC_DIR = $$tmpdir"                       >> $$tmpdir/Makefile && \
	echo "PKGDIR_ABS = $(L4DIR_ABS)/l4defs.gen.dir" >> $$tmpdir/Makefile && \
	cat $(L4DIR)/mk/export_defs.inc                 >> $$tmpdir/Makefile && \
	PWD=$$tmpdir $(MAKE) -C $$tmpdir -f $$tmpdir/Makefile          \
	  CALLED_FOR=$(1) L4DEF_FILE_MK=$(L4DEF_FILE_MK) L4DEF_FILE_SH=$(L4DEF_FILE_SH) && \
	$(RM) -r $$tmpdir

$(L4DEF_FILE_MK): $(BUILD_DIRS) $(DROPSCONF_CONFIG_MK) $(L4DIR)/mk/export_defs.inc
	$(call generate_l4defs_files,prog)
	$(call generate_l4defs_files,lib)

$(L4DEF_FILE_SH): $(L4DEF_FILE_MK)

regen_l4defs:
	$(call generate_l4defs_files,prog)
	$(call generate_l4defs_files,lib)

.PHONY: l4defs regen_l4defs

#####################
# config-rules follow

HOST_SYSTEM := $(shell uname | tr 'A-Z' 'a-z')
export HOST_SYSTEM

# it becomes a bit confusing now: 'make config' results in a config file, which
# must be postprocessed. This is done in config.inc. Then,
# we evaluate some variables that depend on the postprocessed config file.
# The variables are defined in mk/Makeconf, which sources Makeconf.bid.local.
# Hence, we have to 1) postprocess, 2) call make again to get the variables.
DROPSCONF_CONFIG_MK_POST_HOOK:: check_build_tools $(OBJ_DIR)/Makefile
        # libgendep must be done before calling make with the local helper
	$(VERBOSE)$(MAKE) libgendep
	$(VERBOSE)$(MAKE) Makeconf.bid.local-helper || \
		(rm -f $(DROPSCONF_CONFIG_MK) $(CONFIG_MK_REAL) $(CONFIG_MK_INDEP); false)
	$(VEROBSE)$(LN) -snf $(L4DIR_ABS) $(OBJ_BASE)/source
	$(VERBOSE)$(MAKE) checkconf

checkconf:
	$(VERBOSE)if [ ! -e $(GCCDIR)/include/stddef.h ]; then \
	  $(ECHO); \
	  $(ECHO) "$(GCCDIR) seems wrong (stddef.h not found)."; \
	  $(ECHO) "Does it exist?"; \
	  $(ECHO); \
	  exit 1; \
	fi

# caching of some variables. Others are determined directly.
# The contents of the variables to cache is already defined in mk/Makeconf.
.PHONY: Makeconf.bid.local-helper Makeconf.bid.local-internal-names \
        libgendep checkconf
ARCH = $(BUILD_ARCH)
Makeconf.bid.local-helper:
	$(VERBOSE)echo BUILD_SYSTEMS="$(strip $(ARCH)_$(CPU)            \
	               $(ARCH)_$(CPU)-$(BUILD_ABI))" >> $(DROPSCONF_CONFIG_MK)
	$(VERBOSE)$(foreach v, GCCLIBDIR GCCDIR GCCLIB GCCLIB_EH GCCVERSION \
			GCCMAJORVERSION GCCMINORVERSION GCCSUBVERSION   \
			GCCNOSTACKPROTOPT LDVERSION GCCSYSLIBDIRS,      \
			echo $(v)=$(call $(v)_f,$(ARCH))                \
			>>$(DROPSCONF_CONFIG_MK);)
	$(VERBOSE)$(foreach v, LD_GENDEP_PREFIX, echo $v=$($(v)) >>$(DROPSCONF_CONFIG_MK);)
	$(VERBOSE)echo "HOST_SYSTEM=$(HOST_SYSTEM)" >>$(DROPSCONF_CONFIG_MK)
	$(VERBOSE)echo "COLOR_TERMINAL=$(shell if [ $$(tput colors || echo -1) = '-1' ]; then echo n; else echo y; fi)" >>$(DROPSCONF_CONFIG_MK)
	$(VERBOSE)echo "LD_HAS_HASH_STYLE_OPTION=$(shell if $(LD) --help 2>&1 | grep -q ' --hash-style='; then echo y; else echo n; fi)" >>$(DROPSCONF_CONFIG_MK)
	$(VERBOSE)# we need to call make again, because HOST_SYSTEM (set above) must be
	$(VERBOSE)# evaluated for LD_PRELOAD to be set, which we need in the following
	$(VERBOSE)$(MAKE) Makeconf.bid.local-internal-names
	$(VERBOSE)sort <$(DROPSCONF_CONFIG_MK) >$(CONFIG_MK_REAL).tmp
	$(VERBOSE)echo -e "# Automatically generated. Don't edit\n" >$(CONFIG_MK_INDEP)
	$(VERBOSE)grep $(addprefix -e ^,$(CONFIG_MK_INDEPOPTS) ) \
		<$(CONFIG_MK_REAL).tmp >>$(CONFIG_MK_INDEP)
	$(VERBOSE)echo -e "# Automatically generated. Don't edit\n" >$(CONFIG_MK_REAL).tmp2
	$(VERBOSE)grep -v $(addprefix -e ^,$$ # $(CONFIG_MK_INDEPOPTS) ) \
		<$(CONFIG_MK_REAL).tmp >>$(CONFIG_MK_REAL).tmp2
	$(VERBOSE)echo -e 'include $(call absfilename,$(CONFIG_MK_INDEP))' >>$(CONFIG_MK_REAL).tmp2
	$(VERBOSE)if [ -e "$(CONFIG_MK_REAL)" ]; then                        \
	            diff --brief $(CONFIG_MK_REAL) $(CONFIG_MK_REAL).tmp2 || \
		      mv $(CONFIG_MK_REAL).tmp2 $(CONFIG_MK_REAL);           \
		  else                                                       \
		    mv $(CONFIG_MK_REAL).tmp2 $(CONFIG_MK_REAL);             \
		  fi
	$(VERBOSE)$(RM) $(CONFIG_MK_REAL).tmp $(CONFIG_MK_REAL).tmp2

Makeconf.bid.local-internal-names:
ifneq ($(CONFIG_INT_CPP_NAME_SWITCH),)
	$(VERBOSE) set -e; X="tmp.$$$$$$RANDOM.c" ; echo 'int main(void){}'>$$X ; \
		rm -f $$X.out ; $(LD_GENDEP_PREFIX) GENDEP_SOURCE=$$X \
		GENDEP_OUTPUT=$$X.out $(CC) -c $$X -o $$X.o; \
		test -e $$X.out; echo INT_CPP_NAME=`cat $$X.out` \
			>>$(DROPSCONF_CONFIG_MK); \
		rm -f $$X $$X.{o,out};
	$(VERBOSE)set -e; X="tmp.$$$$$$RANDOM.cc" ; echo 'int main(void){}'>$$X; \
		rm -f $$X.out; $(LD_GENDEP_PREFIX) GENDEP_SOURCE=$$X \
		GENDEP_OUTPUT=$$X.out $(CXX) -c $$X -o $$X.o; \
		test -e $$X.out; echo INT_CXX_NAME=`cat $$X.out` \
			>>$(DROPSCONF_CONFIG_MK); \
		rm -f $$X $$X.{o,out};
endif
ifneq ($(CONFIG_INT_LD_NAME_SWITCH),)
	$(VERBOSE) set -e; echo INT_LD_NAME=$$($(LD) 2>&1 | perl -p -e 's,^(.+/)?(.+):.+,$$2,') >> $(DROPSCONF_CONFIG_MK)
endif
	$(VERBOSE)emulations=$$(LANG= $(LD) --help |                     \
	                        grep -i "supported emulations:" |        \
	                        sed -e 's/.*supported emulations: //') ; \
	unset found_it;                                                  \
	for e in $$emulations; do                                        \
	  for c in $(LD_EMULATION_CHOICE_$(ARCH)); do                    \
	    if [ "$$e" = "$$c" ]; then                                   \
	      echo LD_EMULATION=$$e >> $(DROPSCONF_CONFIG_MK);           \
	      found_it=1;                                                \
	      break;                                                     \
	    fi;                                                          \
	  done;                                                          \
	done;                                                            \
	if [ "$$found_it" != "1" ]; then                                 \
	  echo "No known ld emulation found"; exit 1;                    \
	fi

libgendep:
	$(VERBOSE)if [ ! -r tool/gendep/Makefile ]; then	\
	            echo "=== l4/tool/gendep missing! ===";	\
		    exit 1;					\
	          fi
	$(VERBOSE)PWD=$(PWD)/tool/gendep $(MAKE) -C tool/gendep

check_build_tools:
	@unset mis;                                                \
	for i in $(BUILD_TOOLS); do                                \
	  if ! command -v $$i >/dev/null 2>&1; then                \
	    [ -n "$$mis" ] && mis="$$mis ";                        \
	    mis="$$mis$$i";                                        \
	  fi                                                       \
	done;                                                      \
	if [ -n "$$mis" ]; then                                    \
	  echo -e "\033[1;31mProgram(s) \"$$mis\" not found, please install!\033[0m"; \
	  exit 1;                                                  \
	else                                                       \
	  echo "All checked ok.";                                  \
	fi

define entryselection
	unset e; unset ml;                                       \
	   ml=$(L4DIR_ABS)/conf/modules.list;                    \
	   [ -n "$(MODULES_LIST)" ] && ml=$(MODULES_LIST);       \
	   [ -n "$(ENTRY)"       ] && e="$(ENTRY)";              \
	   [ -n "$(E)"           ] && e="$(E)";                  \
	   if [ -z "$$e" ]; then                                 \
	     BACKTITLE="No entry given. Use 'make $@ E=entryname' to avoid menu." \
	       L4DIR=$(L4DIR) $(L4DIR)/tool/bin/entry-selector $$ml 2> $(OBJ_BASE)/.entry-selector.tmp; \
	     if [ $$? != 0 ]; then                               \
	       cat $(OBJ_BASE)/.entry-selector.tmp;              \
	       exit 1;                                           \
	     fi;                                                 \
	     e=$$(cat $(OBJ_BASE)/.entry-selector.tmp);          \
	   fi
endef

BUILDDIR_SEARCHPATH = $(OBJ_BASE)/bin/$(ARCH)_$(CPU):$(OBJ_BASE)/bin/$(ARCH)_$(CPU)/$(BUILD_ABI):$(OBJ_BASE)/lib/$(ARCH)_$(CPU):$(OBJ_BASE)/lib/$(ARCH)_$(CPU)/$(BUILD_ABI)

-include $(L4DIR)/conf/Makeconf.boot
-include $(OBJ_BASE)/conf/Makeconf.boot

image:
	$(VERBOSE)$(entryselection);                                      \
	PWD=$(PWD)/pkg/bootstrap/server/src                               \
	    $(MAKE) -C pkg/bootstrap/server/src ENTRY="$$e"               \
	            BOOTSTRAP_MODULES_LIST=$$ml                           \
		    BOOTSTRAP_MODULE_PATH_BINLIB="$(BUILDDIR_SEARCHPATH)" \
		    BOOTSTRAP_SEARCH_PATH="$(MODULE_SEARCH_PATH)"

qemu:
	$(VERBOSE)if [ "$(ARCH)" != "x86" -a "$(ARCH)" != "amd64" ]; then      \
	  echo "This mode can only be used with architectures x86 and amd64."; \
	  exit 1;                                                              \
	fi
	$(VERBOSE)$(entryselection);                                  \
	   qemu=$(QEMU_PATH);                                         \
	   if [ -z "$$qemu" ]; then                                   \
	     [ "$(ARCH)" = "amd64" ] && qemu=qemu-system-x86_64;      \
	     [ "$(ARCH)" = "x86" ] && qemu=qemu;                      \
	   fi;                                                        \
	 QEMU=$$qemu L4DIR=$(L4DIR)                                   \
	  SEARCHPATH="$(MODULE_SEARCH_PATH):$(BUILDDIR_SEARCHPATH)"   \
	  $(L4DIR)/tool/bin/qemu-x86-launch $$ml "$$e" $(QEMU_OPTIONS)

kexec:
	$(VERBOSE)$(entryselection);                                  \
	 L4DIR=$(L4DIR)                                   \
	  SEARCHPATH="$(MODULE_SEARCH_PATH):$(BUILDDIR_SEARCHPATH)"   \
	  $(L4DIR)/tool/bin/kexec-launch $$ml "$$e"

ux:
	$(VERBOSE)if [ "$(ARCH)" != "x86" ]; then                   \
	  echo "This mode can only be used with architecture x86."; \
	  exit 1;                                                   \
	fi
	$(VERBOSE)$(entryselection);                                 \
	L4DIR=$(L4DIR)                                               \
	  $(if $(UX_GFX),UX_GFX=$(UX_GFX))                           \
	  $(if $(UX_GFX_CMD),UX_GFX_CMD=$(UX_GFX_CMD))               \
	  $(if $(UX_NET),UX_NET=$(UX_NET))                           \
	  $(if $(UX_NET_CMD),UX_NET_CMD=$(UX_NET_CMD))               \
	  SEARCHPATH="$(MODULE_SEARCH_PATH):$(BUILDDIR_SEARCHPATH)"  \
	  $(L4DIR)/tool/bin/ux-launch $$ml "$$e" $(UX_OPTIONS)

grub1iso:
	$(VERBOSE)if [ "$(ARCH)" != "x86" -a "$(ARCH)" != "amd64" ]; then      \
	  echo "This mode can only be used with architectures x86 and amd64."; \
	  exit 1;                                                              \
	fi
	$(VERBOSE)$(entryselection);                                   \
	 $(MKDIR) $(OBJ_BASE)/images;                                  \
	 L4DIR=$(L4DIR)                                                \
	  SEARCHPATH="$(MODULE_SEARCH_PATH):$(BUILDDIR_SEARCHPATH)"    \
	  $(L4DIR)/tool/bin/gengrub1iso --timeout=0 $$ml               \
	     $(OBJ_BASE)/images/$$(echo $$e | tr '[ ]' '[_]').iso "$$e"

grub2iso:
	$(VERBOSE)if [ "$(ARCH)" != "x86" -a "$(ARCH)" != "amd64" ]; then      \
	  echo "This mode can only be used with architectures x86 and amd64."; \
	  exit 1;                                                              \
	fi
	$(VERBOSE)$(entryselection);                                   \
	 $(MKDIR) $(OBJ_BASE)/images;                                  \
	 L4DIR=$(L4DIR)                                                \
	  SEARCHPATH="$(MODULE_SEARCH_PATH):$(BUILDDIR_SEARCHPATH)"    \
	  $(L4DIR)/tool/bin/gengrub2iso --timeout=0 $$ml               \
	     $(OBJ_BASE)/images/$$(echo $$e | tr '[ ]' '[_]').iso "$$e"

.PHONY: image qemu ux switch_ram_base grub1iso grub2iso

switch_ram_base:
	@echo "  ... Regenerating RAM_BASE settings"
	$(VERBOSE)echo "# File semi-automatically generated by 'make switch_ram_base'" > $(OBJ_BASE)/Makeconf.ram_base
	$(VERBOSE)echo "RAM_BASE := $(RAM_BASE)"                                      >> $(OBJ_BASE)/Makeconf.ram_base
	PWD=$(PWD)/pkg/sigma0/server/src $(MAKE) -C pkg/sigma0/server/src
	PWD=$(PWD)/pkg/moe/server/src    $(MAKE) -C pkg/moe/server/src

checkbuild:
	@if [ -z "$(CHECK_BASE_DIR)" ]; then                                  \
	  echo "Need to set CHECK_BASE_DIR variable";                         \
	  exit 1;                                                             \
	fi
	set -e; for i in $(if $(USE_CONFIGS),$(addprefix mk/defconfig/config.,$(USE_CONFIGS)),mk/defconfig/config.*); do \
	  p=$(CHECK_BASE_DIR)/$$(basename $$i);                               \
	  rm -rf $$p;                                                         \
	  mkdir -p $$p;                                                       \
	  cp $$i $$p/.kconfig;                                                \
	  $(MAKE) O=$$p oldconfig;                                            \
	  $(MAKE) O=$$p tool;                                                 \
	  $(MAKE) O=$$p USE_CCACHE=$(USE_CCACHE) $(CHECK_MAKE_ARGS);          \
	done

report:
	@echo -e $(EMPHSTART)"============================================================="$(EMPHSTOP)
	@echo -e $(EMPHSTART)" Note, this report might disclose private information"$(EMPHSTOP)
	@echo -e $(EMPHSTART)" Please review (and edit) before sending it to public lists"$(EMPHSTOP)
	@echo -e $(EMPHSTART)"============================================================="$(EMPHSTOP)
	@echo
	@echo "make -v:"
	@make -v || true
	@echo
	@echo "CC: $(CC) -v:"
	@$(CC) -v || true
	@echo
	@echo "CXX: $(CXX) -v:"
	@$(CXX) -v || true
	@echo
	@echo "HOST_CC: $(HOST_CC) -v:"
	@$(HOST_CC) -v || true
	@echo
	@echo "HOST_CXX: $(HOST_CXX) -v:"
	@$(HOST_CXX) -v || true
	@echo
	@echo -n "ld: $(LD) -v: "
	@$(LD) -v || true
	@echo
	@echo -n "perl -v:"
	@perl -v || true
	@echo
	@echo -n "python -V: "
	@python -V || true
	@echo
	@echo "svn --version: "
	@svn --version || true
	@echo
	@echo "Shell is:"
	@ls -la /bin/sh || true
	@echo
	@echo "uname -a: "; uname -a
	@echo
	@echo "Distribution"
	@if [ -e "/etc/debian_version" ]; then                 \
	  if grep -qi ubuntu /etc/issue; then                  \
	    echo -n "Ubuntu: ";                                \
	    cat /etc/issue;                                    \
	  else                                                 \
	    echo -n "Debian: ";                                \
	  fi;                                                  \
	  cat /etc/debian_version;                             \
	elif [ -e /etc/gentoo-release ]; then                  \
	  echo -n "Gentoo: ";                                  \
	  cat /etc/gentoo-release;                             \
	elif [ -e /etc/SuSE-release ]; then                    \
	  echo -n "SuSE: ";                                    \
	  cat /etc/SuSE-release;                               \
	elif [ -e /etc/fedora-release ]; then                  \
	  echo -n "Fedora: ";                                  \
	  cat /etc/fedora-release;                             \
	elif [ -e /etc/redhat-release ]; then                  \
	  echo -n "Redhat: ";                                  \
	  cat /etc/redhat-release;                             \
	  [ -e /etc/redhat_version ]                           \
	    && echo "  Version: `cat /etc/redhat_version`";    \
	elif [ -e /etc/slackware-release ]; then               \
	  echo -n "Slackware: ";                               \
	  cat /etc/slackware-release;                          \
	  [ -e /etc/slackware-version ]                        \
	    && echo "  Version: `cat /etc/slackware-version`"; \
	elif [ -e /etc/mandrake-release ]; then                \
	  echo -n "Mandrake: ";                                \
	  cat /etc/mandrake-release;                           \
	else                                                   \
	  echo "Unknown distribution";                         \
	fi
	@lsb_release -a || true
	@echo
	@echo "Running as PID"
	@id -u || true
	@echo
	@echo "Archive information:"
	@svn info || true
	@echo
	@echo "CC       = $(CC)"
	@echo "CXX      = $(CXX)"
	@echo "HOST_CC  = $(HOST_CC)"
	@echo "HOST_CXX = $(HOST_CXX)"
	@echo "LD       = $(LD)"
	@echo "Paths"
	@echo "Current:   $$(pwd)"
	@echo "L4DIR:     $(L4DIR)"
	@echo "L4DIR_ABS: $(L4DIR_ABS)"
	@echo "OBJ_BASE:  $(OBJ_BASE)"
	@echo "OBJ_DIR:   $(OBJ_DIR)"
	@echo
	@for i in pkg \
	          ../kernel/fiasco/src/kern/ia32 \
	          ../tools/preprocess/src/preprocess; do \
	  if [ -e $$i ]; then \
	    echo Path $$i found ; \
	  else                \
	    echo PATH $$i IS NOT AVAILABLE; \
	  fi \
	done
	@echo
	@echo Configuration:
	@for i in $(OBJ_DIR)/.config.all $(OBJ_DIR)/.kconfig   \
	          $(OBJ_DIR)/Makeconf.local                    \
		  $(L4DIR_ABS)/Makeconf.local                  \
		  $(OBJ_DIR)/conf/Makeconf.boot                \
		  $(L4DIR_ABS)/conf/Makeconf.boot; do          \
	  if [ -e "$$i" ]; then                                \
	    echo "______start_______________________________:";\
	    echo "$$i:";                                       \
	    cat $$i;                                           \
	    echo "____________________________end___________"; \
	  else                                                 \
	    echo "$$i not found";                              \
	  fi                                                   \
	done
	@echo -e $(EMPHSTART)"============================================================="$(EMPHSTOP)
	@echo -e $(EMPHSTART)" Note, this report might disclose private information"$(EMPHSTOP)
	@echo -e $(EMPHSTART)" Please review (and edit) before sending it to public lists"$(EMPHSTOP)
	@echo -e $(EMPHSTART)"============================================================="$(EMPHSTOP)
