

                       ┌──────╖ ┌─────╖ ┌────╖┌─╖ ┌─────╖
                       │ ╓──┐ ║ │ ╓─┐ ║ │ ╓┐ ║│ ║ │ ╓───╜
                       │ ╙──┘ ║ │ ╙─┘ ║ │ ║│ ║│ ║ │ ╙───╖
                       │ ╓──┐ ║ │ ╓───╜ │ ║│ ║│ ║ └───┐ ║
                       │ ║  │ ║ │ ║     │ ║│ ╙┘ ║ ┌───┘ ║
                       └─╜  └─╜ └─╜     └─╜└────╜ └─────╜


                        Automated Polling Network System


                      Software Version 2.15b - 01/04/1993


                              Manual Revision 2.15


       The APNS software is copyright (c) 1990-1993 Michael E. Ralphson,
                              All Rights Reserved.

      This documentation is copyright (c) 1991-1993 Michael E. Ralphson,
                              All Rights Reserved.





                                  Introduction
                                  ────────────

  The Automated Polling Network System (APNS) is a fully integrated system
  for the automated collection of data from, and transmission of data to, a
  number of remote computer systems (or nodes).

  The system provides full error detection / correction and several specially
  designed security features to ensure complete data integrity and privacy 
  combined with excellent resilience.


                             Hardware Requirements
                             ─────────────────────

  The system software requires the following platform:

  . An IBM AT/PS2 or 100% compatible personal computer (80286 or above)

  . Approximately 85kb of free RAM (minimum)

  . PC-DOS, MS-DOS or DR-DOS version 3.30 or higher, or IBM's OS/2

  . A modem compatible with the Hayes AT command set or similar language

  The software is network compatible and can be loaded into high memory.

  The modem should behave according to PC standards to ensure compatibility.
  In technical terms this means:

  It supports CCITT standards such as V22, V22bis, V32, V32bis
  It should optionally support MNP 2-4 or LAPM / V42 and MNP 5 or V42bis

  The DCD (Carrier Detect) signal should reflect the true state of the
  connection.

  Flow control should be governed by the RTS and CTS signals not XON/XOFF,
  ie: Hardware flow control, not Software.


                                    Overview
                                    ────────

  The APNS system comprises of one main executable program (APNS.EXE) and
  the configuration program (APCONFIG.EXE). User file management is
  carried out with the APFILE.EXE program.

  The APNS program can be used in two modes. The first is dialling mode,
  where the software dials remote nodes, the second is answering mode where
  the software awaits a call from another node.

  Thus the APNS system can be used in three different ways:

   1) Purely for answering incoming calls (eg: a simple Node or Site)

   2) Mostly in polling mode with some answering (eg: a Regional Hub)

   3) Purely in polling mode (eg: a Network Hub)

  It also handles all call and error logging (to a text file called
  APNS.LOG) and the security aspects of the system.


                                  Installation
                                  ────────────

  The installation process has been kept extremely simple and can be carried
  out before the computer system is installed at the remote location, or via
  a remote-control package such as PC-Anywhere.

  From the original distribution diskette, the user should type INSTALL
  followed by the drive letter on which the software should be installed. 
  If no drive letter is specified, the Install program assumes Drive C:

  After confirming the drive letter to install the system onto, the
  installation program will create the following directory structure:

    [DRIVE]:\APNS
    [DRIVE]:\APNS\SEND
    [DRIVE]:\APNS\RECV

  The APNS\SEND and APNS\RECV directories are for outbound and inbound files,
  and operate as if they were electronic IN and OUT trays.

  The \APNS directory will contain the following files:

    APNS.EXE      -  Main executable file
    APNS.CFG      -  Configuration file
    APNS.MOD      -  Modem configuration database
    APCHECK.EXE   -  'Footprint' file utility
    APCOMP.EXE    -  Compares two 'footprint' files and shows differences
    APCONFIG.EXE  -  System configuration program
    APCONFIG.HLP  -  Help for new users of ApConfig
    APFILE.EXE    -  File management and despatch program
    APSCHED.BAT   -  Used to run the Scheduler
    APSCHED0.EXE  -  Schedule file interpreter
    APDELAY.EXE   -  Program to 'waste' time until window begins
    ENCRYPT.EXE   -  File encryption utility

    LHA.EXE       -  File compression utility (third party, public domain)

  In addition, the following files will be created in the \APNS directory
  when APCONFIG has been run:

    APNS.SCH      -  Scheduler's list of events, if required
    APNS.FON      -  List of nodes to dial, if required
    

                 Use of ApConfig for Initial Configuration
                 ─────────────────────────────────────────

  On installation, the Install program automatically changes directory to
  the drive where APNS was installed and runs the ApConfig program.

  Note: the ApConfig program has been designed so that it can be run
  remotely with software such as PcAnywhere IV.


 ╓─┤ Main Menu ├─╖   This is the ApConfig Main Menu.
 ║               ║
 ║░Configuration░║ . For configuration sub-menu
 ║ Node List     ║ . To manipulate nodes in the nodelist
 ║ Scheduler     ║ . To manipulate the schedule file
 ║ Modem List    ║ . To maintain the APNS modem list
 ║ Com-Ports     ║ . Used to check the modem installation
 ║               ║
 ╙───────────────╜

 The user should then select 'Configuration' from this menu.

 ╓────────┤ Setup ├────────╖   This is the ApConfig configuration menu
 ║                         ║
 ║ Screen and colour       ║ . Define on-screen colours and other options
 ║ Filenames and paths     ║ . Define location of send and receive dirs.
 ║ APNS control settings   ║ . Control the way APNS operates
 ║ Modem settings          ║ . Select / modify your modem type
 ║ Communications settings ║ . Tell APNS about your COM port, speed etc
 ║ Undo all changes        ║ . Otherwise they are automatically saved
 ║                         ║
 ╙─────────────────────────╜

 If the user wishes to modify any of ApConfig or APNS's colours then he or
 she should select 'Screen and colour' from this menu.

 ╓────┤ Screen and Colour ├────╖    Most options are self explanatory
 ║                             ║
 ║ Main foreground colour      ║
 ║ Main background colour      ║
 ║ Window foreground colour    ║
 ║ Window background colour    ║
 ║ Highlight foreground colour ║
 ║ Highlight background colour ║
 ║ Window border style         ║
 ║ Sound On                    ║ .  If sound is Off APNS will be silent
 ║ Direct screen writes On     ║ .  You should normally leave this ON
 ║ Snow checking Off           ║ .  Turn this ON if your machine has 'snow'
 ║                             ║
 ╙─────────────────────────────╜

 To return to the Setup Menu when finished, press Escape.

 ╓────────┤ Setup ├────────╖
 ║                         ║
 ║ Screen and colour       ║
 ║░Filenames░and░paths░░░░░║ . Define location of send and receive dirs.
 ║ APNS control settings   ║
 ║ Modem settings          ║
 ║ Communications settings ║
 ║ Undo all changes        ║
 ║                         ║
 ╙─────────────────────────╜

 One of the most important aspects of the initial configuration is defining
 the location of the Apns inbound and outbound directories. As stated above,
 these should always be called \APNS\RECV and \APNS\SEND respectively, but
 care must be taken to ensure that the correct drive letter (C:, D:, E:, F:
 etc) is defined. These directories will be correct as per the drive letter
 specified when the installation program was first run, but will need to be
 modified if the software is moved to another drive or machine.

 From the Setup Menu, select 'Filenames and Paths':

 ╓────────┤ File Setup ├───────╖
 ║                             ║
 ║ Upload path  : C:\APNS\SEND ║ . Only the drive letter should change
 ║ Download path: C:\APNS\RECV ║ . Do not add a backslash (\) or filenames
 ║                             ║
 ╙─────────────────────────────╜

 When you have finished, press Escape to return to the Setup Menu.

 ╓────────┤ Setup ├────────╖
 ║                         ║
 ║ Screen and colour       ║
 ║ Filenames and paths     ║
 ║░APNS░control░settings░░░║ . Control the way APNS operates
 ║ Modem settings          ║
 ║ Communications settings ║
 ║ Undo all changes        ║
 ║                         ║
 ╙─────────────────────────╜

 Returning to the Setup Menu, the 'APNS Control Settings' should be checked to
 ensure the defaults correspond to the manner in which the node will function:

 
 ╓─────────┤ APNS Setup ├──────────╖
 ║                                 ║
 ║ Dial period in seconds    55    ║ . Seconds to wait for connect       
 ║ Inter-dial pause minutes  5     ║ . Minutes between dials to a node   
 ║ Maximum redials of a site 6     ║ . Max. redials of any one node      
 ║ Dial window start hour    23    ║ . APNS dial 'window' starts at 11pm 
 ║ Dial window finish hour   7     ║ . APNS dial 'window' ends at 7am    
 ║ Wait window start hour    23    ║ . APNS wait 'window' starts at 11pm 
 ║ Wait window finish hour   7     ║ . APNS wait 'window' ends at 7am    
 ║ Site identification code  MFOR  ║ . User cannot change this           
 ║ Connect delay in seconds  6     ║ . Modem handshaking delay in seconds
 ║ Exit after one call in    [ ]   ║ . Set to Yes if desired                   
 ║ RTC time can be reset     [X]   ║ . Whether other sites can alter time                                           
 ║ Difference from GMT / CET 0     ║ . Minutes between GMT and local time                                     
 ║ Dial action TIDYOUT.BAT %SITE   ║ . Run after successful call out
 ║ Wait action TIDYIN.BAT %SITE    ║ . Run after successful call in 
 ║ Password    ******              ║ . Security / ApConfig password      
 ║                                 ║
 ╙─────────────────────────────────╜
 
 
The Inter-Dial Pause governs the minimum time between successive dials to 
the same site. With the default value of 5 minutes, APNS will not redial  
any site if it has attempted to dial that site within the past 5 minutes. 
                                                                          
APNS does not wait until the Inter-Dial Pause has expired, it moves on to 
the next diallable site in the nodelist (if any).                         
                                                                          
The values entered for the Answer Window start / finish hours and the     
Dial Window start / finish hours are used by the main program, but        
can be overridden on the APNS command-line. For example:                  
                                                                          
  APNS dial1 DW0306 dial2 wait                                            
                                                                          
 DWssff alters the Dial Window, where ss is the start and ff the finish hour
 WWssff alters the Wait Window, where ss is the start and ff the finish hour

 Altered time windows take effect from their position in the command-line,
 and do not effect the default values entered in ApConfig.

 To continue with the configuration, press Escape to return to the Setup
 Menu.

 ╓────────┤ Setup ├────────╖
 ║                         ║
 ║ Screen and colour       ║
 ║ Filenames and paths     ║
 ║ APNS control settings   ║
 ║░Modem░settings░░░░░░░░░░║ . Select / modify your modem type
 ║ Communications settings ║
 ║ Undo all changes        ║
 ║                         ║
 ╙─────────────────────────╜

 The Modem Setup option allows the user to pick a standard modem from the
 APNS Modem List, and / or modify a standard modem type to tailor the
 configuration to the particular modem.

 ╓─────────┤ Modem Setup ├─────────╖
 ║                                 ║
 ║ Modem name  APNS Standard Modem ║ . User can pick from the Modem List
 ║ Initialise  ATZ|~~~AT&C1&D2|    ║
 ║ Hang up     ~~~+++~~ATH0|       ║ . Then the individual strings can
 ║ Dial prefix ATDT                ║   be modified
 ║ Answer call ATS0=1|             ║
 ║                                 ║
 ╙─────────────────────────────────╜

 If you need to change any of the modem command strings for permanent use, 
 you should return to the main menu and select Modem List. You can then add 
 your modem as a new entry. This will save time on future installations of 
 the same modem. This procedure is fully described in its own section below.

 Again, once you have finished with this menu, press Escape to return to
 the Setup Menu.

 ╓────────┤ Setup ├────────╖
 ║                         ║
 ║ Screen and colour       ║
 ║ Filenames and paths     ║
 ║ APNS control settings   ║
 ║ Modem settings          ║
 ║░Communications░settings░║ . Tell APNS about your COM port, speed etc
 ║ Undo all changes        ║
 ║                         ║
 ╙─────────────────────────╜

 From the Setup Menu again, 'Communications Settings' should be checked to
 ensure that the system is properly configured for your modem:


 ╓─────┤ Comms Setup ├─────╖
 ║                         ║
 ║ Bits per second  19200  ║ . This is the maximum speed of your modem 
 ║ Comms Port No.  2       ║ . APNS supports IBM, ITT/Nokia, Kortex etc
 ║ COM 5 IO Base   0370    ║ . COM 5 is fully user-definable           
 ║ COM 5 IRQ line  3       ║ . The base I/O port address, IRQ and INT  
 ║ COM 5 INT No.   0       ║ . Can be modified for other serial ports  
 ║ Use FIFO buffer [X]     ║ . Activate 16550A FIFO buffer if present  
 ║                         ║
 ╙─────────────────────────╜
 
 
The two most important aspects of communications setups are the COM port
and the speed (BPS or Bits Per Second rate).

If your modem does not use the IBM / Hayes standards for COM Ports 1, 2, 3
and 4, you should consult the following table:


     ╒═══════════════╤═════════════╤═══════════╤══════╤═════╤═════╕
     │ Software Port │  Standard   │    AKA    │ Base │ IRQ │ INT │
     ╞═══════════════╪═════════════╪═══════════╪══════╪═════╪═════╡
     │     COM 1     │ IBM / Hayes │ COM 1 (I) │ 3F8h │  4  │ 0Ch │
     │     COM 2     │ IBM / Hayes │ COM 2 (I) │ 2F8h │  3  │ 0Bh │
     │     COM 3     │ IBM / Hayes │ COM 3 (I) │ 3E8h │  4  │ 0Ch │
     │     COM 4     │ IBM / Hayes │ COM 4 (I) │ 2E8h │  3  │ 0Bh │
     │     COM 5  *  │ Kortex Int. │ COM 3 (K) │ 370h │  4  │ 0Ch │
     │     COM 6     │ Kortex Int. │ COM 4 (K) │ 270h │  4  │ 0Ch │
     │     COM 7     │ Nokia / ITT │ COM 3 (N) │ 3E8h │  5  │ 0Dh │
     │     COM 8     │ Nokia / ITT │ COM 4 (N) │ 3E8h │  2  │ 0Ah │
     └───────────────┴─────────────┴───────────┴──────┴─────┴─────┘

       
 The base I/O port address, IRQ (hardware Interrupt Request line) and
 software Interrupt number are all configurable for the software COM 5 slot.

 The option to locate COM ports from the ApConfig Main Menu can be used
 to discover which Serial (COM) ports are fitted to the computer. To access
 this display, press Escape to return to the Setup Menu, then Escape again
 to return to the ApConfig Main Menu.

 ╓─┤ Main Menu ├─╖
 ║               ║
 ║ Configuration ║
 ║ Node List     ║
 ║ Scheduler     ║
 ║ Modem List    ║
 ║░Com-Ports░░░░░║ . Used to check the modem installation
 ║               ║
 ╙───────────────╜

 Selecting this option will result in a display like the following:

 ╓─────────┤ Com-Ports ├─────────╖
 ║                               ║
 ║      COM 1 is Installed       ║ . COM 1 was detected by the BIOS
 ║      COM 2 is Installed       ║ . COM 2 was detected by the BIOS
 ║      COM 3 was not found      ║ . COM 3 is not present or has a conflict
 ║      COM 4 was not found      ║ . COM 4 is not present or has a conflict
 ║      COM 5 was not found      ║ . COM 5 is the user definable COM port
 ║      COM 6 was not found      ║ . COM 6 is not present or has a conflict
 ║                               ║
 ║      Press any key (09)       ║
 ║                               ║
 ╙───────────────────────────────╜

 The entry for COM 3 may also reflect COM ports 7 and 8 (ITT / Nokia
 standard) if they are present in the machine.


                               The Node List
                               ─────────────

 If the APNS software is to dial any nodes it must also be configured with
 the names, Node Identities and telephone numbers of the nodes that it must
 dial. This again is easily accomplished in the same manner as the preceeding
 configuration menus:

 From the ApConfig Main Menu, select 'Node List':

 ╓─┤ Main Menu ├─╖
 ║               ║
 ║ Configuration ║
 ║░Node List░░░░░║ . To manipulate nodes in the nodelist
 ║ Scheduler     ║
 ║ Modem List    ║
 ║ Com-Ports     ║
 ║               ║
 ╙───────────────╜

 This will take you to the Node List Maintenance menu:

 ╓───────┤ Node List ├────────╖
 ║                            ║
 ║ Add a new entry            ║ . Add a node to your dialling list
 ║ Edit an existing entry     ║ . Make changes to a node
 ║ Delete an existing entry   ║ . Permanently remove a node from the list
 ║ Make all nodes diallable   ║ . Reset all 'days failed' counters to 0
 ║ Make all nodes undiallable ║ . Set all 'days failed' counters to 8 days
 ║ Sort node list by name     ║ . Alphabetically sort the node list
 ║                            ║
 ╙────────────────────────────╜

 All nodes have a 'days failed' counter. If for any reason APNS fails to
 connect to a node during a night, it will increment this flag for that
 node. If this flag reaches 8 days (ie: the node has not been accessible for
 over a week) then APNS will not attempt to connect to that node until this
 flag has been reset.

 Note: This feature is designed to ensure that support personnel at the
 Network Hub keep a close watch on telephone line conditions and modem /
 machine / software performance.

 The user reset this flag from the Dialling Directory Menu (for all nodes)
 or individually from the 'Edit an existing entry' menu.

 The user may wish to set all of the nodes undiallable, before individually
 selecting one or more nodes. This may be used to perform a poll of certain
 nodes outside normal hours, or to prevent communications with certain nodes
 during a normal polling session.

 The next menu is used to Add a new node to APNS's dialling directory. The
 screen is almost identical to the one used to Edit an existing node to make
 changes.


 ╓───────────┤ Edit Node ├───────────╖
 ║                                   ║
 ║ Site Name    Belgian Head Office  ║ . This is for ease of Log readability            
 ║ Site Code    BEHQ                 ║ . As per remote site's APNS License              
 ║ Phone Number 010,32,321123456     ║ . The full telephone number of the node          
 ║ Modem Speed   19200               ║ . The maximum speed of the node's modem          
 ║ When to Dial Always               ║ . Always, When Sending or Never                  
 ║ Dial Session 1                    ║ . Node list can be split into sessions           
 ║ Dial Prefix  ATDT                 ║ . Use ATDP for pulse, ATDT for tone              
 ║ Update Clock [ ]                  ║ . Update their RTC from ours
 ║ Days Failed   0                   ║ . Press RETURN to reset this flag                
 ║ Last Status  Success              ║ . For information only                           
 ║                                   ║
 ╙───────────────────────────────────╜
 
 
 The telephone number of the node's modem should include all necessary
 dialling codes (such as 9 or 0 to obtain an outside line from an internal
 exchange), if a pause is required whilst dialling, use a comma ',' between
 the digits in question.

 If Dialling Session numbers are required, they should be entered for all
 sites using this edit window. Using this method the user can set up
 two different node lists (in effect) and this will allow APNS to
 operate with two separate lists of sites to dial. For example, the
 first group (Session 1) could be the sites 'beneath' the polling site
 in the network structure, and Session 2 could be the other regional
 centres, allowing APNS to first dial the sites in group 1, and then
 those in group 2, possibly with some processing in between.

 A typical multi-session batch file might look something like this:

   @Echo Off
   :
   :Automatic batch file for APNS operation
   :
   CD\Apns
   APNS dial1 dial2 wait

 If the polling machine is in a different time zone (ie: Greenwich Mean Time
 or British Summer Time and Central European Time) then each machine should
 have the Difference To GMT field set to the correct number of minutes
 (plus or minus). For example: Central European Time is normally one hour
 (60 minutes) ahead of GMT/BST. Alternatively the option in the Node List of
 the polling machine to update the Node's Real Time Clock can be set to NO.
 
 If you do not want your machine's real time clock to be updated by any
 other sites, set Clock can be Reset to No in Configuration / APNS settings.


                            The Event Scheduler List
                            ────────────────────────

 The Schedule file is a method of exerting control over a series of actions,
 known within the system as 'Events'.

 It operates similarly to a batch file, but simplifies the decision making
 process of 'events' that must take place only when a certain set of
 circumstances are met.

 The Schedule Interpreter is a seperate program called ApSched0.Exe, this
 performs the processing of the Schedule file you have set-up, and is like
 a batch file with sophisticated decision-making built in.

 The Scheduler Maintenance Menu section of the ApConfig program is similar
 in many respects to the process of defining nodes to dial. You should select
 'Scheduler' from the main menu:


 ╓─┤ Main Menu ├─╖
 ║               ║
 ║ Configuration ║
 ║ Node List     ║
 ║░Scheduler░░░░░║ . To manipulate the schedule file
 ║ Modem List    ║
 ║ Com-Ports     ║
 ║               ║
 ╙───────────────╜

 This will take you to the Scheduler Maintenance Menu.

 ╓─┤ Scheduler ├─╖
 ║               ║
 ║ Add Event     ║ . Add a new event to the end of the event list
 ║ Delete Event  ║ . Remove an event from the event list
 ║ Edit Event    ║ . Make changes to an event
 ║ Sort Events   ║ . Sort events alphabetically by priority
 ║ Next Event    ║ . Manually choose the next event to be run
 ║               ║
 ╙───────────────╜

 The entry screens used to Add and Edit events are almost identical.
 One is shown below:

 ╓──┤ Add Event ├──╖
 ║                 ║
 ║ Event Name :    ║ 
 ║ DOS Command:    ║ 
 ║ Priority   :    ║ 
 ║ Sunday ..... No ║ 
 ║ Monday ..... No ║ 
 ║ Tuesday .... No ║ 
 ║ Wednesday .. No ║ 
 ║ Thursday ... No ║ 
 ║ Friday ..... No ║ 
 ║ Saturday ... No ║ 
 ║ Once a day : No ║ 
 ║ Week Number: 0  ║ 
 ║ Country    : 0  ║ 
 ║ Date active:    ║ 
 ║                 ║
 ╙─────────────────╜

 ╓───────┤ Edit Event ├───────╖
 ║                            ║
 ║ Event Name  Garage Expert  ║ . This is for ease of Log file readability           
 ║ DOS Command GE2            ║ . The required DOS command (.COM, .EXE or .BAT)      
 ║ Priority    AAAA           ║ . Four character alphanumeric priority
 ║ Sunday      [ ]            ║ . If event can run on a Sunday                       
 ║ Monday      [X]            ║ . If event can run on a Monday                       
 ║ Tuesday     [X]            ║ . If event can run on a Tuesday                      
 ║ Wednesday   [X]            ║ . If event can run on a Wednesday                    
 ║ Thursday    [X]            ║ . If event can run on a Thursday                     
 ║ Friday      [X]            ║ . If event can run on a Friday                       
 ║ Saturday    [X]            ║ . If event can run on a Saturday                     
 ║ Once a day  [ ]            ║ . If event should only run once on any date          
 ║ Holidays    [ ]            ║ . If event should run on holidays as well
 ║ Week Number 0              ║ . If event runs only in a certain week number   
 ║ Country     0              ║ . If event runs only in a certain country       
 ║ Date active                ║ . If event runs on a date or range of dates
 ║                            ║
 ╙────────────────────────────╜
 
 The entry for the DOS command required to start the event (this could be
 a .COM or .EXE executable program or a .BAT batch file), can also include
 certain ApSched replaceable parameters. These are:

        %DAY      (example on 18th January 1992)  18
        %MONTH    (example on 18th January 1992)  01
        %YEAR     (example on 18th January 1992)  92
        %DATE     (example on 18th January 1992)  18/01/92

 The 'Country' field can be used to ensure an event is only run in one
 particular country. The codes used are the International Direct Dial codes,
 the same as those used in the COUNTRY= line in CONFIG.SYS. For example:

                           ╒═════════╤══════════╕
                           │ Country │ IDD Code │
                           ╞═════════╪══════════╡
                           │ Belgium │    32    │
                           │ France  │    33    │
                           │ Spain   │    34    │
                           │ Austria │    43    │
                           │ Britain │    44    │
                           └─────────┴──────────┘

 If the Country field is 0, then the event can operate in any country.

 The 'Priority' field is used to list the events in the order you want them
 to occur. When you select 'Sort Events' from the Scheduler Sub-Menu, the
 events are rearranged alphabetically by priority.

 If there are 26 or less entries in the Scheduler, the priorities will be
 reset to AAAA for the first event, BBBB for the second and so on, whenever
 the 'Sort List' option is selected from the menu.

 Care must be taken to understand the method in which scheduled events are
 processed in order to determine whether they run or not.

 The selections above are always taken in combination. Thus if a Week Number
 (1 to 52) is specified, one or more of the Weekdays must also be set to Yes.
 The program logic would check to see if the event can run in the current
 week number (a week number of zero disables this check) and whether the
 event can run on the current week day.

 The same is true of the Date Active field. If this is blank it has no effect
 on the decision making process. If it has an unambiguous date (ie 31/12/93)
 then the event will get run on the thirty-first of December 1993, providing
 that the weekday corresponding to this date is set to Yes. It should be
 normal practice to set all the weekdays to Yes when using the Date Active
 field in this manner.

 The same field can also be used to activate the event on a range of dates.
 If the date active field has any question marks in it, they will be
 replaced each time the Scheduler is run by the corresponding digits of the
 current date. For example:

   Date Active: 01/??/??

 Will run on the first day of every month in every year. The user should
 think of the question marks as 'wildcard' characters (they in fact work
 in a very similar manner to the question mark character in MS-DOS) they
 basically tell the scheduler to ignore those digits.

 The weekdays should all be set to Yes in a similar manner to the above.

 To simplify one difficult case in the Date Active field (the End Of Month,
 as this could be 28th, 29th, 30th or 31st of the month in question), the
 user may simply enter 'ENDMONTH' in the Date Active field.

 Entering anything in the Date Active field will cause all the weekdays to
 be set to Yes.
 
 The Holidays check box controls whether the event will run on days defined
 by the system administrator as holidays. Automatic events such as end of
 period reports or nightly communications should normally be set to run
 regardless of whether the day is a holiday, but any events which require
 the operator to be present (perhaps the main event of the day which runs
 the user's application program) should be set not to run on holidays.
 
 This would usually be for events which are already set up to run on
 weekdays and possibly Saturdays, but not Sundays.
 
 To define holidays, the system administrator should create a text file
 in the \APNS directory called HOLIDAYS.TXT (the file can be created with
 any text editor which produces clean Ascii files, such as DOS's EDIT or
 even EDLIN, if you use a word-processor it should be in non-document mode).
 
 The format of the file is simply a date on each line of the file starting 
 in the first column and in DD/MM/YY format. For example:
 
 01/05/93
 25/12/93
 26/12/93
 01/01/93

                              The APNS Modem List
                              ───────────────────

 To enter Modem List Maintenance, select Modem List from the Main Menu:

 ╓─┤ Main Menu ├─╖
 ║               ║
 ║ Configuration ║
 ║ Node List     ║
 ║ Scheduler     ║
 ║░Modem List░░░░║ . To maintain the APNS Modem List
 ║ Com-Ports     ║
 ║               ║
 ╙───────────────╜

This will take you to the Modem List Maintenance Menu, it follows a similar
form to the Node-List and Schedule Maintenance Menus:

 ╓──┤ Modems ├──╖
 ║              ║
 ║ Add Modem    ║ . Add a new modem to the APNS Modem List
 ║ Edit Modem   ║ . Make changes to a modem in the Modem List
 ║ Delete Modem ║ . Permanently delete a modem from the Modem List
 ║ Sort List    ║ . Alphabetically sort the Modem List
 ║ Import Text  ║ . Import a text version of the Modem List
 ║ Output Text  ║ . Create a text version of the Modem List
 ║              ║
 ╙──────────────╜

 The options to Edit or Delete a Modem will display the Modem List and allow
 you to choose a modem from it:

 ╓──────────────────┤ Edit ├───────────────────╖
 ║                                             ║
 ║░░░░░░░░░░░░░░░░APNS░Standard░░░░░░░░░░░░░░░░║
 ║         AST Premium Exec Modem 2400         ║
 ║        AT&T Paradyne COMSPHERE 3800         ║
 ║        AT&T V32F-V42L Modem Chipset         ║
 ║        AT&T V32x-V42D Modem Chipset         ║
 ║             Accex External 9600             ║
 ║               Codex 2264/2266               ║
 ║             CompuCom Champ MKII             ║
 ║               CompuCom Combo                ║
 ║             CompuCom Combo MKII             ║
 ║            Dallas Fax 14.4 Nova             ║
 ║          Dallas Fax 14.4 Pro Plus           ║
 ║          Dallas Fax 2496 External           ║
 ║          Dallas Fax 2496 Internal           ║
 ║          Dallas Fax 2496V External          ║
 ║          Dallas Fax 2496V Internal          ║
 ║           Dallas Fax 2496V Pocket           ║
 ║            Dallas Fax 9696 Nova             ║
 ║                                             ║
 ╙─────────────────────────────────────────────╜

 The Modem Entry window is used when you either Add or Edit a modem:

 ╓─────────┤ Edit Modem ├─────────╖
 ║                                ║
 ║ APNS Modem Type: APNS Standard ║ . Descriptive name for this modem-type
 ║ Initialisation : ATZ|~~~AT&C1| ║ . Modem initialisation string
 ║ Dial prefix    : ATDT          ║ . Modem dialling prefix
 ║ Auto-Answer On : ATS0=1|       ║ . Modem command to enable auto-answer
 ║ Hang up connect: ATH0|         ║ . Modem command to hang-up the modem
 ║                                ║
 ╙────────────────────────────────╜

 The options to import and export textual versions of the APNS Modem List
 are for use when the Modem List has to be updated from modifications made
 out at site.

                                 File Transfer
                                 ─────────────

 Files sent and received by APNS must be named according to the following
 convention:

   <ORIG><DEST>.<EXT>

 Where ORIG is the node ID of the origin of the file, DEST is the node ID of
 the destination of the file, and EXT is any extension.

 If the DESTination is '-ALL' then the file will be sent to any node that
 connects.
 
 If the DESTination is '-Snn' then the file will be sent to any node that
 connects, as long as that node is a member of Dialling Session number 'nn'.

 For example, a file being sent from an organisation's UK Head Quarters (UKHQ) 
 to their Frence counterparts (FRHQ) would have the following name:

   UKHQFRHQ.LZH
   
 The extension of the file is not important to APNS.  

 A price update file sent from France to all sites it connects with (ie sites 
 that either dial in to, or are dialled by FRHQ) would have the following name:

   FRHQ-ALL.LZH

 If a -ALL file is sent to all sites, it is deleted automatically. If it is
 not sent to any sites then the -ALL file is left in the \APNS\SEND directory
 and attempts will be made to send the file the next night.

 If a -ALL file is sent to one or more sites, then individual copies of the
 file are created in the \APNS\SEND directory addressed to the sites that have
 not received the -ALL file. For example:

 If the file FRHQ-ALL.LZH is sent to all sites except F101 and F107, then the
 following files will be created in the \APNS\SEND directory:

   FRHQF101.LZH
   FRHQF107.LZH

 And the original FRHQ-ALL.LZH file will be deleted.

 The two copies of APNS will exchange node-codes and passwords, to establish
 their respective identities, as well as the polling node's current system
 time and date (if this is desired) etc etc.

 APNS will only transmit those files intended for the node it has connected to,
 the file naming convention above allows for a true network of nodes to be
 set up in which regions can poll other regions, associate nodes can poll
 each other and a full international, inter-region and inter-node system
 is possible in which reports, program updates and data modification as well
 as electronic mail are all available, using the APNS system to the full.

 Packets in the inbound and outbound directories can have one of four
 statuses:

                               Inbound Directory

    DIRECT      The packet is intended for this node or all nodes
    ROUTED      The packet is intended for another node in the network
    LOCAL       The packet originates from this node, operator error
    MISNAMED    The packet does not have an eight character filename

                               Outbound Directory

    DIRECT      The packet originates from this node
    ROUTED      The packet originates from another node in the network
    LOCAL       The packet is intended for this node, operator error
    MISNAMED    The packet does not have an eight character filename

    
                       Operation Of APNS (Dialling Mode)
                       ─────────────────────────────────

 To start the system, after the system has been setup then it is a simple
 matter to change to the \APNS directory and then to the following DOS command
 for dialling mode:

   APNS DIAL (C/R)

 Dialling mode is the default, so the command APNS (C/R) will produce the
 same result. (C/R) represents the Enter or Carriage Return key.

 To select a different Dial Session, simply append the desired session
 number to the end of the command. For example:

   APNS DIAL2 (C/R)

 This command would start APNS in dialling mode, using Dial Session number
 2 instead of 1, which is the default. Dialling Sessions are discussed
 further in the section dealing with node list maintenance.

 If configured correctly (see the section on installation above) the modem
 will be initialised and then dial the node that was setup as the first node
 in the list.

 If the modem fails to initialise, APNS will abort immediately, and log the
 error in the APNS.LOG file. To correct this error, you should manually
 reset the modem (if this is possible) and also run APCONFIG to ensure that
 the modem settings and communications settings match your modem and COM
 Port.

 APNS will only dial between the times defined with the ApConfig program,
 if the program is started before the dialling start time in ApConfig, then
 APNS will wait without dialling until it is allowed to do so.

 The system will begin with the first Node in the nodelist and attempt to
 connect with it.

 If the two modems connect, then the polling copy of APNS will wait for the
 line to settle and then try to initiate a handshake session with the polled
 Node. It attempts this ten times, and will then abort if it does not
 receive an acknowledgement of the handshake.

 Once a handshake session has begun, both copies of APNS send a 'packet' of
 identity data, including Site Code, security password and number of files
 to send.

 If there is any security violation, either copy of APNS may immediately
 drop the line, logging this information to the APNS.LOG file. Otherwise,
 the transfer of files will begin. Only files intended for the receiving
 Node will be sent (regardless of the original sender).

 Thus if the UK Head Office (Node ID UKHQ) polls Site U110, the exchange
 of files might go like this:

   File: UKHQ-ALL.LZH will be sent from UKHQ to U110 (Status DIRECT)
   File: UKHQU110.LZH will be sent from UKHQ to U110 (Status DIRECT)
   File: UKHQ-S02.LZH will be sent from UKHQ to U110 (Status DIRECT)

   File: U113UKHQ.LZH will be sent from U110 to UKHQ (Status ROUTED)
   File: U110UKHQ.LZH will be sent from U110 to UKHQ (Status DIRECT)

 Note the '-ALL' file which is sent to U110, because such a file would be
 sent to any site that connected with UKHQ, the '-S02' file which is sent 
 to U110 because it is a member of Dialling Session 2, and the file 
 originally from U113 that was routed through U110 and then continues on to 
 its eventual destination: UKHQ.
 
 APNS will only look for files to send in the \APNS\SEND directory, and
 all incoming files are stored in the \APNS\RECV directory.

 If there is a successful connection, APNS will 'flag' that Node as having
 been successful and proceed to the next Node in the nodelist.

 If for any reason APNS fails to connect with a Node (telephone number
 engaged, excessive line noise etc), it will flag that Node as having failed
 and continue through the nodelist.

 APNS will continue cycling through the nodelist until all Nodes have been
 successfully polled (or they have been dialled the maximum number of times)
 or the APNS polling time-window defined in APCONFIG has finished.


                      Operation Of APNS (Waiting Mode)
                      ────────────────────────────────

 To start the system in Waiting for a Call mode, change into the \APNS
 directory and type:

   APNS WAIT (C/R)

 (This can of course be accomplished using a batch file, or more usefully as
 part of an End Of Day scheduler entry.) If the program is started before
 the Answer Start Hour defined in ApConfig, then APNS will wait (not
 accepting calls) until the Answer Start Window begins.

 The software will initialise the modem and wait for a call, answering the
 modem between the times defined with the ApConfig program.

 If the option has been set in ApConfig to exit after one call (ApConfig /
 Configuration / APNS Control Settings), then APNS will not wait until the
 answer window has ended, but will exit immediately after the first fully
 successful session.


                                  Security
                                  ────────

 The security of the system is based around the two copies of APNS
 exchanging handshake information. The handshake packets contain a master
 password which may be changed by authorised personnel to effectively lock
 out any 'rogue' copies of APNS.

 Either end may terminate the connection if a security violation occurs. The
 software will only allow data to be transfered to the destination that it
 is intended for.

 All nodes within the system have a unique node ID, which is a 4 character
 string, for example U113. This feature gives the system the capability to
 use full inter-node addressing. This means that all files to be transmitted
 are treated as data-packets with an origin and destination, allowing nodes
 to poll each other for data (electronic mail, file exchange, franchise
 information etc), and provides the ability to route files through the
 network from a Node in one Area to any other Node or Network Hub in the
 system.
 
 Note: File routing is only available if your data files are archived
 with the LHA compression utility.

 All site coding is will be done in the UK and each Site's Node ID is
 hard coded into the configuration file APNS.CFG. The software will not 
 operate if this configuration file is tampered with in any way.


                            File Management (ApFile)
                            ────────────────────────

 The APNS File Manager (ApFile) screen display is split into two windows.
 The first shows a list of all the sub-directories of the current directory
 and all the files in the current directory.

 The second window shows help for the function keys used within ApFile.

 14/10/1992 │ ApFile, APNS File Manager version 2.15                  20:58:45
 ╓─────────────────┤ C:\APNS ├─────────────────╖╓───┤ Function Key Guide ├───╖
 ║                                             ║║                            ║
 ║  ..           ── DIR ── 09/10/1992 18:33:24 ║║ Return selects file or dir ║
 ║  RECV         ── DIR ── 09/10/1992 18:33:28 ║║                            ║
 ║  SEND         ── DIR ── 09/10/1992 18:33:26 ║║   F1 to Route the file     ║
 ║  APCONFIG.EXE     26488 13/10/1992 10:54:32 ║║   F2 to Route to -ALL      ║
 ║  APCONFIG.HLP      4126 10/10/1992 02:15:00 ║║   F3 to Send  to -ALL      ║
 ║  APDELAY .EXE      7796 10/10/1992 02:15:00 ║║   F4 to Sort by Name       ║
 ║  APFILE  .EXE     15752 10/10/1992 02:15:00 ║║   F5 to Sort by Extension  ║
 ║░░APNS░░░░.CFG░░░░░░1024░14/10/1992░17:56:32░║║   F6 to Sort by Date       ║
 ║  APNS    .EXE     26304 14/10/1992 20:55:12 ║║   F7 to Sort by Size       ║
 ║  APNS    .FON      1536 10/10/1992 02:15:00 ║║   F8 for an Unsorted list  ║
 ║  APNS    .LOG      1395 14/10/1992 20:55:30 ║║                            ║
 ║  APNS    .MOD     22755 10/10/1992 02:15:00 ║║   + / - to Tag / Untag     ║
 ║  APNS    .SCH      2304 10/10/1992 02:15:00 ║║                            ║
 ║  APNSENG1.CFG      1024 10/10/1992 02:15:00 ║║                            ║
 ║  APNSLIN1.CFG      1024 10/10/1992 02:15:00 ║║                            ║
 ║  APNSPOL1.CFG      1024 10/10/1992 02:15:00 ║║                            ║
 ║  APNSVIE1.CFG      1024 10/10/1992 02:15:00 ║║                            ║
 ║  APNSVIE2.CFG      1024 10/10/1992 02:15:00 ║║                            ║
 ║  APSCHED .BAT        49 10/10/1992 02:15:00 ║║                            ║
 ║                                             ║║                            ║
 ╙─────────────────────────────────────────────╜╙────────────────────────────╜
 Use Up, Down, PageUp, PageDown, Home, End and A..Z to choose


 Selecting a file by pressing Return will present the user with a list
 of sites. The user should then select a site to send the file or files to.

 If the F1 key is used instead of Return, then the list of sites is displayed
 twice. The first time to select the eventual destination of the file(s) and
 the second time to select the site through which the file(s) will be routed.

 If the F2 key is used instead of Return, then the list of sites is only
 displayed once. This is for the user to select the site through which the
 file(s) will be routed. Once the files reach the intermediate site, then
 they will be sent on to ALL sites that connect with that site. For example:

 The head office in the UK wants to send an update to all the sites in
 France. They can route the file(s) through the French head office, using
 F2 to ensure that the file(s) continue on to all of the sites dialled by
 the French head office machine.

 When they are received at the intermediary site, the file(s) will be
 automatically re-addressed to their eventual destination site.

 The F3 function key allows sending one or more files to -ALL sites that
 the local site communicates with.

 In the filename display, the subdirectories of the current directory are
 always listed at the top of the list. The special directory '..' is a
 short-hand way of specifying the directory above the current directory.

 For instance, if the current directory is \APNS\SEND then selecting '..'
 will change directory to \APNS. If '..' is selected again, then ApFile
 will change directory to the root directory of the current drive. When you
 are viewing the root directory of the drive, you can also select a
 different drive letter to change to.

 The function keys from F4 to F8 re-sort the directory display, as
 indicated in the function key guide above.

 To exit ApFile at any stage, the user should press Escape.


                                   Appendix A
                                   ──────────

                          Additional Support Utilities
                          ────────────────────────────

                                    ApDelay
                                    ───────

 ApDelay is used to bridge the gap between the end of a normal day's activity
 at a site and the start of the APNS Answer Window. Normally, APNS would be
 active at this time, but would not answer incoming calls. If this period
 (usually in the evening) is needed to be used for support calls, for example
 by PC-Anywhere, APNS must not be running.

 ApDelay is simply a bouncing-ball effect screen-saver that will operate
 from the time it is invoked to the start of the APNS Answer Window.


                                   Appendix B
                                   ──────────

                   The File Transfer Protocol Implementation
                   ─────────────────────────────────────────

 The file-transfer protocol Xmodem was created by Ward Christensen in 1981. It
 was simpler to implement, more reliable and faster than other methods being
 used at the time.

 The original Xmodem sent data in 128 byte blocks, with a one-byte checksum to
 protect against data errors. As modems became faster, both a larger block-size
 and more sophisticated error-checking were required. Both of these were simply
 added as optional features to Xmodem, so that any two Xmodem implementations
 could transfer data using the best combination of methods common to both
 receiver and sender.

 Under Xmodem, the vast majority of the data is naturally being sent from the
 transmitting computer to the receiving computer. After each block is received,
 its CRC (Cyclic Redundancy Check, a method of treating the data as one long
 number, dividing it by an agreed number and taking the remainder) or checksum
 value is compared to one generated at the receiving end. If these do not match
 then an error has occurred (usually due to noise on the telephone line) and
 the receiver requests that the block be transmitted again. This continues
 until the block is successfully received or the maximum number of consecutive
 errors (ten) occurs. If this happens it is almost always better to abort the
 transfer (APNS uses a very secure method to agree on aborts, to avoid one end
 mistakenly believing an abort request has occurred), hang-up and then later
 retry in order to get a better connection.

 The Xmodem implementation in APNS supports 1024 byte data blocks and CCITT 16
 bit CRC error detection. In a change from the standard Xmodem CRC / 1K
 implementation, the APNS file transfer protocol includes these improvements:

  1) Initial ACK / NAK handshake replaced by packetised exchange of file
     information (size, time, date etc).

  2) The CRC check includes all protocol supervisory information (the current
     block number etc) to prevent line noise corrupting any part of the data
     packet.

 These combine to give throughput and data integrity rates approaching those of
 protocols such as Zmodem, but with a lower processing overhead. To further
 improve the Xmodem performance, APNS utilises a fast look-up table to generate
 CRCs rather than calculating them for each byte (this has been tested and
 found to be faster than a good assembler algorithm) and combines a large input
 buffer with an interrupt driven receive routine that prevents any incoming
 data from being lost.

 By these various methods APNS can achieve a throughput approaching the maximum
 possible (between 90% and 96% on reasonable lines) for modems not equipped
 with MNP or other hardware error correction systems, while not impairing any
 of the benefits of increased throughput and data reliability provided by
 modems that do have MNP, V42Bis etc.

                                      END

