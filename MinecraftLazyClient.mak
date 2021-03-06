# Minecraft Lazy Client v2.1
# (for the new launcher of Minecraft version >= 1.6.1)

# GitHub: https://github.com/yipo/minecraft-lazy-client
# Author: Yi-Pu Guo (YiPo)
# License: MIT


packing:

# The action target is `packing' by default.


SOURCE_DIR ?= source

# Where the script to retrieve required materials.

LAUNCHER_JAR ?= minecraft.jar

# The filename of the launcher, is the official jar executable by default.
# The .exe one is capable, but larger in file size.

BASED_ON_VER ?= 1.6.1

# The version to install mods on,
# or the name of the corresponding folder in `.minecraft\versions\'.
# To install Forge, it should be in the form like `1.7.10-Forge10.13.2.1230'.

MOD_LIST ?=

# - Syntax:
# MOD_LIST = [<target> ...]
# <target> = <mod-name>.<method>
# <method> = mod | mlm

# - Example:
# MOD_LIST = ModLoader.mod OptiFine.mod InvTweaks.mlm ReiMinimap.mlm

# If MOD_LIST is empty, `first-run' will be skipped,
# and just a pure, portable Minecraft package is generated.

# ** mod-name: the name of the mod.
# To install the specified mod, the script automatically searches for
# the filename matches the patten `*<mod-name>*.jar' (or .zip) in $(SOURCE_DIR).
# Example: `ReiMinimap.mlm' can match `[1.6.4]ReiMinimap_v3.4_01.zip'.

# If multiple files are matched, the last one in alphabetical order
# (usually the newest one in version) will be picked.

# Instead of auto search, write a rule to explicitly specify the filename.
# Example:
# OptiFine.mod: OptiFine_1.8.1_HD_U_C7.jar

# ** method: the way to install the mod.
# mod: traditional mods (add .class files into the .jar file in `versions\').
# mlm: Forge/ModLoader mods (copy the .jar/.zip file to `mods\').

OUTPUT_FILE ?= MinecraftLazyClient.7z

# The filename of the output package.
# Note that the filename extension decides the compression method.

PACKING ?=

# - Syntax:
# PACKING = [$(<predef-const>) ...] [<file-path> ...]
# <predef-const> = PL_SETT | PL_SERV | PL_SAVE | PL_RSPK

# - Example:
# PACKING = $(PL_SETT) $(PL_SERV) .minecraft\config\InvTweaks*.txt

# To add additional files or folders into the package,
# specify the path related to $(mc_dir), or the constants as follows.

# PL_SETT: the minecraft settings.
# PL_SERV: the server list.
# PL_SAVE: the `save\' folder.
# PL_RSPK: the `resourcepacks\' folder.

PL_SETT = .minecraft\options.txt
PL_SERV = .minecraft\servers.dat
PL_SAVE = .minecraft\saves
PL_RSPK = .minecraft\resourcepacks

# Note that a '\' at the end of a line means splitting lines in makefile.

JAVA_ARGS ?=

# To set `JVM Arguments' in the profile editor.


.PHONY: initial portable-basis first-run install-mods post-processing packing
.PHONY: uninstall-mods packing-clean clean super-clean

.SUFFIXES:
.SUFFIXES: %.mod %.mlm

SHELL = cmd.exe

VPATH = $(SOURCE_DIR)

mc_dir = MinecraftLazyClient
mc_bat = $(mc_dir)\Minecraft.bat
mc_lch = $(mc_dir)\.minecraft\mc-launcher.jar
mc_pfl = $(mc_dir)\.minecraft\launcher_profiles.json
mc_lib = $(mc_dir)\.minecraft\libraries
mc_ver = $(mc_dir)\.minecraft\versions
mc_mod = $(if $(forge),$(mc_mod_fg),$(mc_mod_ml))

# For shorter names.

forge = $(findstring Forge,$(BASED_ON_VER))

mc_lib_fg = $(mc_lib)\net\minecraftforge

mc_mod_fg = $(mc_dir)\.minecraft\mods
mc_mod_ml = $(des_dir)\mods

# Note that Forge and ModLoader have different paths to `mods\'.

ori = $(firstword $(subst -, ,$(BASED_ON_VER)))
sou = $(BASED_ON_VER)
des = $(ori)-mlc

ori_dir = $(mc_ver)\$(ori)
sou_dir = $(mc_ver)\$(sou)
des_dir = $(mc_ver)\$(des)

ori_jar = $(ori_dir)\$(ori).jar
sou_jar = $(sou_dir)\$(sou).jar
sou_jsn = $(sou_dir)\$(sou).json
des_jar = $(des_dir)\$(des).jar
des_jsn = $(des_dir)\$(des).json

im_mod = $(filter %.mod,$(MOD_LIST))
im_mlm = $(filter %.mlm,$(MOD_LIST))

define \n


endef

# The new line character.

fix_path = $(subst /,\,$1)

# Convert the path from Unix style to Windows style.

ok_msg = @echo [$1] OK

run_mc = $(mc_bat) /WAIT

# Run Minecraft by the same way $(mc_bat) does, but wait for termination.


initial: $(SOURCE_DIR) tool\7za.exe tool\jq.exe
	$(call ok_msg,$@)

$(SOURCE_DIR) tool:
	md $@

tool\7za.exe tool\jq.exe: | tool
	@echo ** Please download $(notdir $@) from $(link_$(basename $(notdir $@))),
	@echo ** and place it in the tool folder.
	@exit 1

link_7za = http://www.7-zip.org/
link_jq  = http://stedolan.github.io/jq/


portable-basis: initial $(mc_bat) $(mc_lch)
	$(call ok_msg,$@)

$(mc_bat) $(mc_dir)\.minecraft: | $(mc_dir)
$(mc_lch): | $(mc_dir)\.minecraft

# To avoid being directly executed (not portable),
# the launcher is hidden in `.minecraft\'.

$(mc_dir) $(mc_dir)\.minecraft:
	md $@

$(mc_bat):
	>  $@ echo @ECHO OFF
	>> $@ echo SET APPDATA=%%~dp0
	>> $@ echo CD "%%~dp0\.minecraft"
	>> $@ echo START %%* javaw -jar mc-launcher.jar

# %* is for the /WAIT flag in $(run_mc).

$(mc_lch): $(LAUNCHER_JAR)
	copy /Y $(call fix_path,$<) $@ > nul


first-run: portable-basis restore
	$(call ok_msg,$@)

# This step is annoying and wasting time.
# So once it has been done, it will not update anymore.
# When update is really needed, just `make clean' and do it all again.

$(ori_dir): | portable-basis
	@echo ** Please login, take the first run of the version $(ori)
	@echo ** and then quit the game manually.
	$(run_mc)

$(mc_lib_fg): $(ori_dir) | $(SOURCE_DIR)/forge-*-*-installer.jar
	@echo ** Please install Forge.
	set APPDATA=$(mc_dir)&& javaw -jar $(lastword $|)

# Note that `&&' must right behind the $(mc_dir), or
# any space will cause the value of APPDATA wrong.

$(sou_dir): $(if $(forge),$(mc_lib_fg))

.PHONY: restore

restore: $(sou_dir) $(if $(im_mod),restore-jar) restore-jsn

rsjsn_jq = .id = \"$(des)\" $(if $(im_mod),| del(.inheritsFrom))

restore-jar restore-jsn: | $(des_dir)

$(des_dir):
	md $@

restore-jar: $(wildcard $(des_jar))
	copy /Y $(sou_jar) $(des_jar) || copy /Y $(ori_jar) $(des_jar)
	> $@ echo.

restore-jsn: $(wildcard $(des_jsn)) Makefile
	jq "$(rsjsn_jq)" < $(sou_jsn) > $(des_jsn)
	> $@ echo.

# `restore-*' targets restore $(des_*) only when they were modified.


install-mods uninstall-mods: $(if $(MOD_LIST),first-run,portable-basis)
	$(call ok_msg,$@)

.PHONY: -im-mod-clean -im-mod -im-mlm-clean -im-mlm

# It's not recommended to execute these targets directly.

install-mods: $(if $(im_mod),-im-mod-clean -im-mod)
install-mods: $(if $(im_mlm),-im-mlm-clean -im-mlm)

uninstall-mods: -im-mod-clean -im-mlm-clean

# Execute the `uninstall-mods' target to remove all the installed mods.


-im-mod-clean:
	-rd /S /Q extract

-im-mod: $(im_mod)
	-copy extract\*.jar $(des_dir) > nul
	cd extract && 7za a $(CURDIR)\$(des_jar) * -x!*.jar > nul
	7za d $(des_jar) META-INF > nul
	$(call ok_msg,$@)

# Installation of manual-install mods:
# - Only .jar files (if any) will be copied to $(des_dir).
# - The others will be added in $(des_jar).
# - The `META-INF' folder in $(des_jar) will be deleted.

extract:
	md $@

$(im_mod): | extract

%.mod:
	@echo [$@] $<
	7za x $(call fix_path,$<) -oextract -y > nul

# The order of targets in MOD_LIST does matter.
# If any files are conflicted, the former will be overwrite by the latter.


-im-mlm-clean:
	-rd /S /Q $(mc_mod)

-im-mlm: $(im_mlm)
	$(call ok_msg,$@)

$(mc_mod):
	md $@

$(im_mlm): | $(mc_mod)

%.mlm:
	@echo [$@] $<
	copy $(call fix_path,$<) $(mc_mod) > nul

# Installation of the mods require ModLoader:
# Simply copy the .jar/.zip file to $(mc_mod).

# Make sure ModLoader is also installed if there are mods depend on it.
# This script will not check this for you.


auto_match_pattern = $(SOURCE_DIR)/*$(basename $(notdir $1))*.*

# Find the `*<mod-name>*.jar' (or .zip) file in $(SOURCE_DIR) folder.
# `.*' because makefile does not support regular expression like `.(jar|zip)'.

auto_match = $1: $(lastword $(wildcard $(call auto_match_pattern,$1)))

# Take the last one in alphabetical order.

$(foreach i,$(MOD_LIST),$(eval $(call auto_match,$(i))))


post-processing: install-mods

# Users can do something before packing.
# Note that don't let this target become the default target.
# (i.e. This target should not be the first target in your makefile.)
# (Or just define this target below the include statement of this makefile.)

# The variables in this makefile like $(mc_dir), $(\n), $(ok_msg), etc
# can be used in the user-defined recipes.
# Running Minecraft again, use $(run_mc).


packing: install-mods post-processing packing-clean $(OUTPUT_FILE)
	$(call ok_msg,$@)

packing-clean:
	-del $(OUTPUT_FILE) packing-list

$(OUTPUT_FILE): packing-list default-profile
	-7za a $@ @packing-list

# Ignore file-not-found warnings by adding the leading hyphen.

ifneq ($(forge),)
PACKING += .minecraft\libraries\net\minecraftforge
PACKING += .minecraft\libraries\org\scala-lang
PACKING += .minecraft\libraries\com\typesafe
JAVA_ARGS += -Dfml.ignoreInvalidMinecraftCertificates=true
JAVA_ARGS += -Dfml.ignorePatchDiscrepancies=true
endif

packing-list:
	>  $@ echo $(des_dir)
	>> $@ echo $(mc_mod)\*.jar
	>> $@ echo $(mc_mod)\*.zip
	>> $@ echo $(mc_pfl)
	>> $@ echo $(mc_lch)
	>> $@ echo $(mc_bat)
	$(foreach i,$(PACKING),>> $@ echo $(mc_dir)\$(i)$(\n))

# Actually, only few things are needed to make a package.

define dfpfl_jq
{
  profiles: {
    "(Default)": {
      name: "(Default)",
      lastVersionId: "$(des)",
      javaArgs: "$(JAVA_ARGS)"
    }
  },
  selectedProfile: "(Default)",
  clientToken,
  authenticationDatabase: {}
}
endef

default-profile: $(mc_pfl)
	jq "$(subst $(\n),,$(subst ",\",$(dfpfl_jq)))" < $< > $@
	type $@ > $<
	del $@

# Remove private information and set the selected version.

$(mc_pfl):
	> $@ echo.

# Create a dummy file, if $(mc_pfl) does not exist.


clean: packing-clean
	-rd /S /Q $(mc_dir) extract
	-del restore-jar restore-jsn

super-clean: clean
	-rd /S /Q tool $(SOURCE_DIR)

