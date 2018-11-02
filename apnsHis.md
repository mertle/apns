2.15b April 1993
───> ApConfig now uses the Utility library (reduced memory requirements)
───> ApFile fixed bug changing to a floppy drive with no disk present
───> Added disk buffering to the receive file routine (helps at 9600+ bps)
───> Changed from a percentage to actual cps rate on file transfer
───> Localised block receive and CRC routines in file transfer
───> Fixed bug if using WAITONCE then another WAIT command on the cmd-line
───> Fixed bug in time/date transfer from poller to polled
───> Inter-dial pause rewritten using new code for time/date transfer
───> User can edit / delete multiple records more easily now 
───> Fixed bug, ApConfig always said the config had changed in Apns.Log
───> ApComp, added extension-exclusion list for comparing footprints
───> Added ability to send a file to all members of a dialling session -Snn
───> Terminal mode window is now full screen (24 lines)
───> All disk intensive routines now use the same buffer strategy
───> Fixed bug, now checks for WhenSend sites with no files every 5 mins
───> Added facility to scheduler to take account of holidays

2.15 October 1992 - March 1993
───> Encrypted configuration file
───> Won't attempt to dial if sitecode or telephone number is blank
───> Routing multiple files to same destination now works ok
───> Will only clean up files in RECV directory if they contain routed files
───> Reads .LZH files with level 0 and level 1 headers (Route.Inc)
───> Messages before modem initialisation are in correct window now
───> Added tagging of files to send / route in ApFile
───> Rewrote HangUp again, to prevent modem retrain latching onto dialtone
───> Tidied up the display during file transfer
───> More network aware, won't trash files it can't open
───> Install program will modify upload and download dirs automatically
───> ApFile now uses the Utility library
───> Modified the way days failed is recorded for WhenSend and Never sites
───> ApFile mods for multiple drive letters
───> GMT difference using new Unix-style dates, or old method
───> Deleting records in ApConfig (modems, events, sites) improved
───> Scheduler: User can set a country-code for events
───> Improvements to Routing (to -ALL), and Routing and Sending to same site
───> Files to -ALL that don't go to all sites are sent individually
───> ApFile: Send to -ALL, releases file buffer memory for shell to LHA
───> APNS original date and time is maintained on transferred files
───> Removed log summary file creation
───> ApFile, increased number of files that can be read per directory to 2500
───> Ability to process inbound files in historical order
───> Fixed problem quitting when there are only WhenSend sites left to dial
───> Added multiple dialling sessions, to effectively split the nodelist
───> Multiple parameters on the startup command-line (actions, time windows)
───> Fixed cosmetic bug validating Date Active field in Scheduler Events
───> Added very simple terminal mode for accessing modem direct
───> Added option to control whether site's clock is updated from remote
───> Changed compiler to Borland Pascal v7.00
───> Added new limited demo which transfers files but zeroes contents
───> Eliminated need for English.Inc (added Translate utility)
───> ApSched would run ENDMONTH events on Saturday if Sunday was the month end

2.10 September 1992, Added ApFile file manager / sender / router
───> Fixed bug in ApConfig screen colours setup
───> Made the session password the ApConfig password as well, and hid display
───> Improved the help for ATDT and ATDP dial prefix selection
───> Added display of which Com ports were located by the BIOS
───> Optional control of when a site is dialled, everyday, when sending, never
───> Added control over 'DEMO' site-codes, won't answer or dial out
───> CRC routine is now slightly quicker
───> Applied Borland's fix to the Delay procedure for 486 machines
───> Fixed the bug that made APNS repeatedly start and exit for an hour
───> Altered status line and made screen windows wider
───> Cleaned up some old unused variables in ApConfig
───> Rewrote the way the 'PickList' window works on databases
───> User defined COM 5 is detected by Com Ports display
───> Added facility to import and export the Modem List as a text file
───> Modem list now contains 100+ entries, all UK / European models
───> Fixed bug; APNS would wait until 5 mins past any hour before dialling
───> ApConfig will load in less memory, just Sorting won't work
───> Detects 8088 and 8086 processors and exits gracefully

2.02 Fixed bps rate display on the status line
───> Window display positions fixed on return from DOS
───> Display of all packets in SEND/RECV directories, misnamed packets etc
───> BPS rate changes back to setup value before re-initialisations
───> Packets to '-ALL' are listed in inbound / outbound displays
───> Standard defaults are present when Add A New Modem is selected
───> Fixed bug that would allow COM0 in ApConfig
───> Imported 50 new modems into the APNS list
───> 'Modified' is added to the modem name when a standard cfg is changed
───> Added APDELAY to allow incoming support calls
───> Defaults for timeslot are 23 -> 07
───> Added support for 16550-AFN Fifo communications buffers
───> Added first letter selection to any 'PickList' window (ApConfig)
───> Improved ApConfig logging, and queries on save / delete
───> Dial window starts at 5 minutes past the hour
───> In ApConfig, scheduler priorities are set to AAAA, BBBB etc after sort
───> APNS logging modified slightly
───> ApDelay logs access to DOS and support window close-downs
───> Summary of dialling activity written to APNS.SUM
───> Modified the way junk characters are receieved in Wait For A Call
───> When all sites have been dialled, or the six attempts are up, APNS aborts
───> Code for oneway transfers was buggy, corrected to reflect send/recv order
───> Added config switch for use of 16550 Fifo buffers, Kortex again
───> ApConfig can no longer change the line parameters from 8N1

2.01 Added display of current function in bottom left-hand corner
───> Fixed display of received strings
───> Added extra room for expansion in the various APNS data files
───> Made updating the site's clock optional for each site (for international)

{ From version 2, version numbers will only change when programs are       }
{ not comms compatible, or there is a major advance in the software.       }
{ Revisions of the software that are comms compatible will have a one      }
{ letter suffix, eg. version 2.15b supercedes 2.15 but is still compatible }

2.00 June 1992, Modem list capability
───> New display code

1.50 File transfer code rewritten

1.11 Handshake packets allow space for further expansion

1.10 'Aurora Wait' incorporated into APNS.EXE

1.07 Half way house to seperate programs (v1.10) never used
───> Bug: (0.90-1.06) handshake only used 8 bit checksum not 16 bit CRC

1.06 Debugging version
───> Comms-compatible with version 1.04
1.05 ApConfig extended to configure scheduler
───> Included polling delay for often-retried numbers
───> Added checks for Pc-Anywhere and Carbon Copy TSRs
───> Comms-compatible with version 1.04
1.04 June 1991, Reversed APNS / Aurora send / receive order
───> ApConfig extracted to allow online configuration

1.03 Fixed handshaking problems
───> this is incompatible with previous versions as the handshaking packets
───> contain records for time and date transfer

1.02 Changed compiler to Turbo Pascal v6.00
───> Definable delay to avoid MNP train problems
1.01 Bug fixes from release version
───> Added broadcast file extension '.LZH' received by all sites

1.00 March 1991, bug in handshake

0.97 Field Beta Test
0.95 Field Beta Test
0.90 October 1990, Initial testing

