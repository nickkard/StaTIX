#!/bin/sh
# Build of the StaTIX
# The only optional parameter is the jar output dir

USAGE="$0 [-p] [-c] [-v] [<outdir>]
  -p,--pack - build the tarball besides the executables
  -c,--classes  - retain classes after the build, useful for the frequent
    modification and recompilation of some files.
    
    Compilation or the single file (.java to .class):
    $ javac -cp lib/\*:src -d classes/ src/info/exascale/statix/main.java
"
# Extract the leading "-" if any:  ${1%%[^-]*}
# Process input options
TARBALL=0  # Make tarball
DELCLS=1  # Delete the classes after the jar building
VERBOSE=0  # Verbose output, useful to identify errors

while [ $1 ]
do
	case $1 in
	-p|--pack)
		TARBALL=1
		shift  # Shift the arguments
		;;
	-c|--classes)
		DELCLS=0
		shift
		;;
	-v|--verbose)
		VERBOSE=1
		shift
		;;
	-*)
		printf "Error: Invalid option specified.\n\n$USAGE"
		exit 1
		;;
	*)
		# Check that only one output directory is specified
		if [ -n "${2}"  ]
		then
			printf "Error: Too many parameters specified.\n\n$USAGE"
			exit 1
		fi
		break
		;;
	esac
done

OUTDIR=${1:-.}  # Output directory for the executable package
CLSDIR="$OUTDIR"/classes  # Classes output directory
APP=statix  # App name

JCFLAGS=""  # Java compiler flags
if [ $VERBOSE -ge 1 ]; then
	JCFLAGS="-Xdiags:verbose"
fi

# Create the output dir if not exists
mkdir -p $CLSDIR  # 2> /dev/null

# Set revision to the sources
# REV="`git rev-parse HEAD`(`git log -1 --format=%ci --`)"
# The shortened hash of the current commit:
# git rev-parse --short HEAD
# or (the same as)
# git log --pretty=format:'%h' -1
REV="`git rev-parse --short HEAD`"
MAINFILE="src/info/exascale/statix/main.java"
MARKER='^\(\s*public static final String \s*clirev = \"\)'
# Check whether build is outside the repository
if [ $? -ne 0 ]
then
	REV=""
else
	# Check whether the last commit is modified
	git diff-index --quiet HEAD --
	if [ $? -ne 0 ]
	then
		# Use current time for the modified revision
		REV="$REV+ (`date --rfc-3339=seconds`)"  #  -u
	else
		# Fetch the revision time from the git repository
		REV="$REV (`git log --pretty=format:'%ci' -1`)"  # Add time
	fi
	# Substitute revision to the sources
	# Note: return 1 if the substitution has not been made
	sed -i "/${MARKER}/"',$'"{s/${MARKER}[^\"]*\"/\1$REV\"/;b}"';$q1' "$MAINFILE"
	if [ $? -ne 0 ]
	then
		echo "Error: revision marker was not found in the $MAINFILE"
		exit 0
	fi
fi
# Compile, exit on error
echo "Compiling the classes in the \"$CLSDIR\", revision: $REV..."
javac $JCFLAGS -cp lib/\* -sourcepath src -d "$CLSDIR" src/info/exascale/statix/*.java
ERRCOMPILE=$?
# Recover the original sources
if [ -n "$REV" ]
then
	sed -i "s/${MARKER}[^\"]*\"/\1\"/" "$MAINFILE"
fi
# Manual compilation of the specific class:
# $ javac -cp lib/\* -sourcepath src -d classes/ src/info/exascale/statix/main.java
if [ $ERRCOMPILE -ne 0 ]
then
	echo "Build failed, errcode: $ERRCOMPILE"
	exit $ERRCOMPILE
fi

# Make the jar file ------------------------------------------------------------
echo Building the ${APP}.jar in the \"$OUTDIR\" from \"$CLSDIR\"...
# Note: other jars are not included to this one for the easier substitution of the components
# and to avoid specification of the explicit manifest file (class path)
# Adequate arguments are supported only by Java 9+
# jar -c -e info.exascale.statix.main -f "$OUTDIR"/${APP}.jar -C "$CLSDIR" .
# Own syntax is required in Java8-
jar -cef info.exascale.statix.main "$OUTDIR"/${APP}.jar -C "$CLSDIR" .
if [ $? -ne 0 ]
then
	echo "Build failed, errcode: $?"
	exit $?
fi

# Remove the compiled classes
if [ $DELCLS -ne 0 ]
then
	echo "Removing the \"$CLSDIR\""
	rm -rf "$CLSDIR"
fi

# Copy requirements to the output dir
if [ "$OUTDIR" != "." ]
then
	cp -a lib/ run.sh "$OUTDIR"
fi

# Build the tarball ------------------------------------------------------------
if [ $TARBALL -ne 0 ]
then
	echo "Building the tarball in the \"$OUTDIR\"..."
	./pack.sh "$OUTDIR" "$OUTDIR"
fi
