# WHOSON Command

`WHOSON` is a TSO command, written in REXX, that will generate a report
of all, or selected, TSO and SSH users on all the systems within the SYSPLEX.
Will also report on zOSMF users (which includes Zowe Explorer users).

*Notes:*
 - the system level and IPL date and time are also reported for each LPAR.
 - only zOSMF users who use files or JES servics that start a TSO addres
space can be detected (step starts with IZU or procstep has lowercase).

As a subroutine with the Q option, the results will be placed in the
TSO stack where a REXX PULL can be used to access it.

### Also report on any other address spaces
 - find *custom* and follow instructions
 - looks for the `ICH70001I` message in the JESMSGLG to report on the user

Will also work as an OMVS Shell command and has been included as
`whoson.rex` in the git distribution for that purpose.

## Installation

Copy the exec into a library in your `SYSEXEC`, or `SYSPROC`, allocated
libraries.

For use under OMVS copy the `whoson.rex` exec into an OMVS
directory in your `PATH` and then `chmod +x whoson` and then tag as
IBM-1047 (`chtag -tc 1047`).

## Dependencies:

   * SDSF REXX
   * RACF LU command
   * less (shell command)

### Notes
If the user is not authorized to issue the RACF `lu` command for the
requested userid then the name associated with the userid will be blank.
