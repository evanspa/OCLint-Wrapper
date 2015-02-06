#!/bin/bash

################################################################################
## Copyright (C) 2013 Paul Evans
##
## Permission is hereby granted, free of charge, to any person obtaining a copy
## of this software and associated documentation files (the "Software"), to
## deal in the Software without restriction, including without limitation the
## rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
## sell copies of the Software, and to permit persons to whom the Software is
## furnished to do so, subject to the following conditions:
##
## The above copyright notice and this permission notice shall be included in
## all copies or substantial portions of the Software.
##
## THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
## IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
## FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
## AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
## LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
## FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
## IN THE SOFTWARE.
################################################################################

################################################################################
#                                                                              #
# Author: Paul Evans                                                           #
# Description:                                                                 #
#    Convenience script to execute OCLint against an iOS code base.            #
#                                                                              #  
################################################################################

###########################################
#  Constants                              #
###########################################
readonly TOOL_NAME=${BASH_SOURCE[0]}
readonly XCODEBUILD_LOG="xcodebuild.log"
readonly COMPILE_CMDS_JSON="compile_commands.json"
readonly HTML_REPORT="oclint_result.html"
readonly OCLINT_INSTALL_DIR=~/Downloads
readonly USAGE_HELP="Usage:    $TOOL_NAME xcode-project scheme sdk configuration architecture\n\
Example:  $TOOL_NAME helloworld.xcodeproj helloworld i386 Debug iphonesimulator7.0"

###########################################
#  OCLint version / download info         #
###########################################
readonly OCLINT_VERSION="oclint-0.8.dev.2888e0f"
readonly OCLINT_DOWNLOAD_FILE="$OCLINT_VERSION-x86_64-darwin-12.4.0.zip"
readonly OCLINT_DOWNLOAD_URL="http://archives.oclint.org/nightly/$OCLINT_DOWNLOAD_FILE"
readonly OCLINT_HOME=$OCLINT_INSTALL_DIR/$OCLINT_VERSION

#####################################################
#  Assign command-line args to meaningful variables #
#####################################################
readonly XCODEPROJ="$1"
readonly SCHEME="$2"
readonly SDK="$3"
readonly CONFIGURATION="$4"
readonly ARCH="$5"

###########################################
# Validate command-line arguments         #
###########################################
if [[ $# -ne 5 ]]; then
    echo -e "Invalid argument set passed.\n$USAGE_HELP"
    exit -1
fi

###########################################
# Download OCLint if necessary            #
###########################################
if [[ ! -d "$OCLINT_HOME" ]]; then
    echo -e "OClint not found on machine.  Proceeding to download it."
    curl -L -o $OCLINT_INSTALL_DIR/$OCLINT_DOWNLOAD_FILE $OCLINT_DOWNLOAD_URL
    currentDir=$( pwd )
    cd $OCLINT_INSTALL_DIR
    unzip -o $OCLINT_DOWNLOAD_FILE &> /dev/null
    echo -e "OCLint downloaded successfully."
    cd $currentDir
else
    echo -e "OCLint is currently installed at: [$OCLINT_HOME]."
fi

###########################################
# remove previously generated stuff       #
###########################################
echo -e "Removing existing configuration and reports."
derivedBuildDir=$( dirname $( dirname $( dirname $( xcodebuild -project $XCODEPROJ -showBuildSettings | grep "BUILT_PRODUCTS_DIR = /Users" | awk -F "=" '{print $2}' ) ) ) )
if [[ $( basename $( dirname $derivedBuildDir ) ) == "DerivedData" ]]; then
    echo -e "Deleting contents of derived build dir: [$derivedBuildDir]"
    rm -rf $derivedBuildDir/* &> /dev/null
else
    echo -e "Error retrieving derived data folder.  Exiting."
    exit -1
fi
rm $XCODEBUILD_LOG &> /dev/null
rm $COMPILE_CMDS_JSON &> /dev/null
rm $HTML_REPORT &> /dev/null

###########################################
# Generate xcodebuild.log                 #
###########################################
echo -e "Invoking xcodebuild to generate xcodebuild.log file."
xcodebuild -project $XCODEPROJ -scheme $SCHEME -sdk $SDK -configuration $CONFIGURATION -arch $ARCH > $XCODEBUILD_LOG

###########################################
# Generate compile_commands.json          #
###########################################
echo -e "Invoking oclint-xcodebuild to product compile_commands.json file."
$OCLINT_HOME/bin/oclint-xcodebuild &> /dev/null

###########################################
# Do lint check and generate HTML report  #
###########################################
echo -e "Invoking oclint-json-compilation-database to perform lint check on all source files."
$OCLINT_HOME/bin/oclint-json-compilation-database -- -report-type html -o $HTML_REPORT
echo -e "Lint check complete.  HTML report generated at: ./$HTML_REPORT"
