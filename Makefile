# This file is part of CO𝘕CEPT, the cosmological 𝘕-body code in Python.
# Copyright © 2015–2023 Jeppe Mosgaard Dakin.
#
# CO𝘕CEPT is free software: You can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# CO𝘕CEPT is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with CO𝘕CEPT. If not, see https://www.gnu.org/licenses/
#
# The author of CO𝘕CEPT can be contacted at dakin(at)phys.au.dk
# The latest version of CO𝘕CEPT is available at
# https://github.com/jmd-dk/concept/



# This is the main makefile for the CO𝘕CEPT code.
# You typically do not need to interact with this file directly,
# but instead use the concept script to build and run the code.
# This makefile accepts the option
#   build
# which sets the build directory.

# Use the Bash shell
SHELL = /usr/bin/env bash



##############################
# Specification of filenames #
##############################
# List of files and directories in the util directory
# generated by using the utilities.
files_util =   \
    update_new \



###############################################
# Environment information from the .path file #
###############################################
# Get the path to the .path file
path_filename = $(shell                             \
    search() {                                      \
        for path in $(MAKEFILE_LIST); do            \
            path="$$(readlink -f "$${path}")";      \
            path="$$(dirname "$${path}")";          \
            while [ "$${path}" != "/" ]; do         \
                if [ -f "$${path}/.path" ]; then    \
                    path_filename="$${path}/.path"; \
                    echo "$${path_filename}";       \
                    return;                         \
                fi;                                 \
                path="$$(dirname "$${path}")";      \
            done;                                   \
        done;                                       \
    };                                              \
    search;                                         \
)
ifeq ($(path_filename),)
    $(error Could not find the .path file)
endif
# Include (absolute) paths from the .path file
include $(path_filename)
# Read in the paths
path = $(shell grep -o '.*=' $(path_filename) | sed 's/.$$//')



#############
# Functions #
#############
# Function for displaying headings based on the value
# of the 'building' variable.
define heading
    $(python) -B -c "pass;                                                         \
        import sys;                                                                \
        sys.exit() if '$(heading_printed)' else None;                              \
        import re;                                                                 \
        import blessings;                                                          \
        extra = [];                                                                \
        extra.append('native optimizations')                                       \
            if '$(native_optimizations)' == 'True'                                 \
                and '$(no_optimizations)' != 'True'                                \
            else None;                                                             \
        extra.append('no link time optimizations')                                 \
            if '$(no_lto)' == 'True'                                               \
                and '$(no_optimizations)' != 'True'                                \
            else None;                                                             \
        extra.append('no optimizations')                                           \
            if '$(no_optimizations)' == 'True'                                     \
            else None;                                                             \
        extra.append('unsafe')                                                     \
            if '$(unsafe_building)' == 'True'                                      \
            else None;                                                             \
        extra.append('serially')                                                   \
            if re.search(r'^ *(-j|--j|--jo|--job|--jobs)=? *1$$', '$(make_jobs)')  \
            else None;                                                             \
        extra = (' (' + ', '.join(extra) + ')')                                    \
            if extra                                                               \
            else '';                                                               \
        terminal = blessings.Terminal(force_styling=True);                         \
        print(terminal.bold_yellow('\nBuilding $(building)' + extra), flush=True); \
    "
    $(eval heading_printed = True)
    sleep 0.05
endef
# Function which takes in one or more quoted or unquoted arguments.
# If these are paths (perhaps prefixed with e.g. -I) located near
# the current directory, the return value is the relative path.
# Otherwise, the return value is just the untouched argument.
sensible_path = $(shell                                                    \
    depth=2;                                                               \
    slow_but_general=False;                                                \
    if [ -n "$2" ]; then                                                   \
        cd "$2";                                                           \
    fi;                                                                    \
    current_dir="$$(pwd)";                                                 \
    print_str="";                                                          \
    for p in $1; do                                                        \
        for prefix in "-I" "-L" "-Wl,-rpath=" ""; do                       \
            if [[ "$${p}" == "$${prefix}"* ]]; then                        \
                n=$$(echo "$${prefix}" | awk '{print length}');            \
                p="$${p:$${n}}";                                           \
                break;                                                     \
            fi;                                                            \
        done;                                                              \
        if [ "$${slow_but_general}" == "True" ]; then                      \
            suffix="";                                                     \
            n=$$(echo "$${p}" | awk '{print length - 1}');                 \
            end="$${p:$${n}:1}";                                           \
            if [ "$${end}" == "/" ]; then                                  \
                suffix="/";                                                \
            fi;                                                            \
            p="$$(readlink -m "$${p}")$${suffix}";                         \
        else                                                               \
            if [ "$${p:0:1}" != "/" ]; then                                \
                print_str="$${print_str} $${prefix}$${p}";                 \
                continue;                                                  \
            fi;                                                            \
        fi;                                                                \
        if [ "$${p}" == "$${current_dir}" ]; then                          \
            p=".";                                                         \
        elif [[ "$${p}" == "$${current_dir}/"* ]]; then                    \
            n=$$(echo "$${current_dir}" | awk '{print length + 1}');       \
            p="$${p:$${n}}";                                               \
        else                                                               \
            back="";                                                       \
            upper_dir="$${current_dir}";                                   \
            for ((i = 0; i < $${depth}; i += 1)); do                       \
                upper_dir="$$(dirname "$${upper_dir}")";                   \
                if [ "$${p}" == "$${upper_dir}" ]; then                    \
                    p="..$${back}";                                        \
                    break;                                                 \
                elif [[ "$${p}" == "$${upper_dir}/"* ]]; then              \
                    n=$$(echo "$${upper_dir}" | awk '{print length + 1}'); \
                    p="..$${back}/$${p:$${n}}";                            \
                    break;                                                 \
                fi;                                                        \
                back="$${back}/..";                                        \
            done;                                                          \
        fi;                                                                \
        print_str="$${print_str} $${prefix}$${p}";                         \
    done;                                                                  \
    print_str="$$(echo $${print_str})";                                    \
    echo "$${print_str}";                                                  \
)
# Function for eliminating duplicates
define unique
$(shell $(python) -B -c "pass;
    import re;
    unique_word_patterns = {r'^-D', r'^-I', r'^-L', r'^-O', r'^-W', r'^-l'};
    words = [word for word in '$1'.split() if word];
    words_prev = set();
    words = [(word, words_prev.add(word))[0] for word in words if not word in words_prev
        or not any(re.search(pattern, word) for pattern in unique_word_patterns)
    ];
    print(' '.join(words));
")
endef



##############################
# Checks and transformations #
##############################
# Check whether the Python interpreter works.
# Error out if not.
python_test = $(shell $(python) -B -c "print('success')")
ifneq ($(python_test),success)
    $(error Try sourcing the concept script)
endif
# Transform all the included paths to sensible paths
# to reduce screen clutter when building.
$(foreach p,$(path),$(eval $(p)=$(call sensible_path,$($(p)))))
# If no $(build) directory is defined, use the default build_dir
ifeq ($(build),)
    build = $(build_dir)
endif



###########
# Targets #
###########
# For building the code in the $(build) directory
all:
	@mkdir -p "$(build)"
	@for f_src in "$(src_dir)"/*; do                                       \
	    f_base="$$(basename "$${f_src}")";                                 \
	    f_build="$(build)/$${f_base}";                                     \
	    if [ -f "$${f_build}" ]; then                                      \
	        t_src=$$(stat -c '%Y' "$${f_src}");                            \
	        t_build=$$(stat -c '%Y' "$${f_build}");                        \
	        [ "$${t_build}" -le "$${t_src}" ] || continue;                 \
	    fi;                                                                \
	    cp "$${f_src}" "$${f_build}";                                      \
	    if [ "$${f_base}" == "Makefile" ]; then                            \
	        Makefile="$$(readlink -f "$(concept_dir)")/Makefile";          \
	        sed -i "s/\.\.\/Makefile/$${Makefile//\//\\/}/" "$${f_build}"; \
	    fi;                                                                \
	done
	@$(MAKE) -C "$(build)" --no-print-directory
.PHONY: all
# For building the documentation
doc:
	@$(MAKE) -C "$(doc_dir)" --no-print-directory
.PHONY: doc
# For printing makefile variables
print-vars:
	$(foreach var, $(.VARIABLES), $(info $(var) = $($(var))))
.PHONY: print-vars



###################
# Cleanup targets #
###################
.PHONY:                   \
    clean                 \
    clean-autosave        \
    clean-doc             \
    clean-ic              \
    clean-job             \
    clean-output          \
    clean-reusable        \
    clean-bispec-reusable \
    clean-class-reusable  \
    clean-ewald-reusable  \
    clean-fftw-reusable   \
    clean-test            \
    clean-tmp             \
    clean-util            \
    distclean             \
    distclean-except-tmp  \

# Remove build files
clean:
	$(RM) -r "$(build_dir)"
# Remove files generated via autosave
clean-autosave:
	$(RM) -r "$(ic_dir)/autosave"
# Remove documentation build
clean-doc:
	@$(MAKE) -C "$(doc_dir)" clean-sphinx --no-print-directory
# Remove everything in the ic directory
clean-ic:
	$(RM) -r "$(ic_dir)"/* "$(ic_dir)"/.[^.]*
# Remove everything in the job directory
clean-job:
	$(RM) -r "$(job_dir)"/* "$(job_dir)"/.[^.]*
# Remove everything in the output directory
clean-output:
	$(RM) -r "$(output_dir)"/* "$(output_dir)"/.[^.]*
# Remove reusable dumps
clean-reusable:
	$(RM) -r "$(reusable_dir)"
clean-bispec-reusable:
	$(RM) -r "$(reusable_dir)/bispec"
clean-class-reusable:
	$(RM) -r "$(reusable_dir)/class"
clean-ewald-reusable:
	$(RM) -r "$(reusable_dir)/ewald"
clean-fftw-reusable:
	$(RM) -r "$(reusable_dir)/fftw"
# Remove files produced by running tests
clean-test:
	$(RM) -r "${test_dir}"/*/artifact
# Remove files produced by the utilities
clean-util:
	$(RM) -r $(addprefix "$(util_dir)"/,$(files_util))
# Remove the tmp directory, generated by various scripts
clean-tmp:
	$(RM) -r "$(tmp_dir)"
# Remove all unnecessary files,
# leaving CO𝘕CEPT in a distribution ready state.
# Note that with the exception of autosaves,
# no files in the ic or output directories will be removed.
distclean-except-tmp: \
    clean             \
    clean-autosave    \
    clean-doc         \
    clean-job         \
    clean-reusable    \
    clean-test        \
    clean-util        \

distclean: distclean-except-tmp clean-tmp

