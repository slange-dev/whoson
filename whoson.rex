/* REXX */
  /* --------------------  rexx procedure  -------------------- *
  | Name:      WHOSON                                          |
  |                                                            |
  | Function:  Using SDSF REXX query for all TSO users and     |
  |            all SSH users on all systems in the SYSPLEX.    |
  |                                                            |
  |            Also detect zOSMF users. For zOSMF oly those    |
  |            users using files or JES services that create   |
  |            a TSO address space that can be detected by a   |
  |            proc step name with lowercase, or a stepname    |
  |            starting with IZU.                              |
  |                                                            |
  |            Also report on any other address spaces         |
  |            - find *custom* and follow instructions         |
  |                                                            |
  | Syntax:    %whoson option \ prefix-or-filter               |
  |                                                            |
  |            option: B - ISPF Browse results *               |
  |                    V - ISPF View results *                 |
  |                    Q - Place results in the TSO Stack *    |
  |                    null - REXX say                         |
  |                    ? - display help info                   |
  |                                                            |
  |            prefix - any char string prefixing userid       |
  |                     e.g. SPL                               |
  |            filter - any chars within a userid              |
  |                     e.g. *L or L*                          |
  |                                                            |
  |            * - if running under the shell will be converted|
  |                to using the less shell command             |
  |                                                            |
  | Dependencies:  SDSF REXX                                   |
  |                RACF LU                                     |
  |                                                            |
  | Customizations:  1. Change RACFLU variable from 1 to 0     |
  |                     - if you don't have RACF               |
  |                     - if made available to those who can't |
  |                       do an LU for other userids.          |
  |                  2. Other define other started tasks to    |
  |                     check by reading the JESMSGLG and      |
  |                     extracting the ICH... userid           |
  |                                                            |
  | Author:    Lionel B. Dyck                                  |
  |                                                            |
  | History:  (most recent on top)                             |
  |            2025/05/29 LBD - Check for SHELL and use less   |
  |            2025/05/28 LBD - Remove STEMEDIT dependency     |
  |            2025/05/26 LBD - Add Q option                   |
  |            2024/11/21 LBD - Change LU rc check for > 4     |
  |            2024/07/17 LBD - For zOSMF/Zowe check proc for  |
  |                             IZU in addition to lowercase   |
  |            2024/07/16 LBD - Report 'human' dates instead of|
  |                             julian dates                   |
  |            2024/07/15 LBD - Fixup zOSMF & remove Zowe flag |
  |                           - Clean up title (less space)    |
  |            2024/07/14 LBD - Adjust zOSMF flag to zOSMF/Zowe|
  |            2024/07/13 LBD - Detect zOSMF users (may be     |
  |                             zowe explorer users)           |
  |            2024/06/27 LBD - Improve report layout          |
  |            2024/06/26 LBD - Add LPAR IPL Info              |
  |            2024/06/24 LBD - Allow multiple others          |
  |            2024/06/21 LBD - Add date/time for users        |
  |            2024/06/19 LBD - Clean up                       |
  |                           - can't use dates                |
  |            2024/06/05 LBD - Fix one more bug with other    |
  |            2024/06/04 LBD - Clean up SDSF for Other        |
  |            2024/06/03 LBD - Add Other users                |
  |                             implemented for Gateway z/OS   |
  |                             web TSO address spaces         |
  |            2024/01/31 LBD - Enable to run under OMVS shell |
  |                           - correct for names with ,'s     |
  |                             with text before , going last  |
  |            2023/11/06 LBD - Sort lpar names                |
  |            2023/11/05 PJF - Clean up filters for PS        |
  |            2023/10/31 LBD - Fix for filtering              |
  |            2023/10/28 LBD - Fix if racflu is 1 but s/b 0   |
  |            2023/10/26 LBD - Split Total users into TSO/SSH |
  |            2023/10/23 LBD - Add ssh users                  |
  |            2022/03/31 LBD - Add option to bypass RACF LU   |
  |            2022/03/14 LBD - Use SDSF DA instead of RO cmd  |
  |                           - add filter option              |
  |                           - Fix case of user name          |
  |            2022/03/11 LBD - Cleanup/improve report         |
  |            2022/03/04 LBD - Creation                       |
  |                                                            |
  * ---------------------------------------------------------- */

  arg option '\' prefix .

  /* -------------- *
  | Check for Help |
  * -------------- */
  if strip(option) = '?' then call do_help

  /* -------------------- *
  | Define key variables |
  * -------------------- */
  parse value '' with null lpars users. tpref
  upper = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'

  /* ------------------------------------------------------------ *
  | Site Customizations   *custom*                               |
  |                                                              |
  |    RACFLU - allow or disallow doing an LU to get the name of |
  |             the TSO users.                                   |
  |                                                              |
  |             0 = Do not allow                                 |
  |             1 = Allow                                        |
  |                                                              |
  |    OTHER  - other address space names, or prefixes, to       |
  |             report on                                        |
  |                                                              |
  |             null = ignore                                    |
  |             ABC = look just for ABC                          |
  |             AB* = look for prefix AB                         |
  |                                                              |
  * ------------------------------------------------------------ */
  RACFLU = 1
  OTHER  = null

  /* -------------------------- *
  | Enable SDSF Rexx Interface |
  * -------------------------- */
  x = isfcalls('on')

  /* --------------------------------- *
  | Check and configure Prefix/Filter |
  * --------------------------------- */
  if length(prefix) > 0 then do
    if pos('*',prefix) > 0
    then tpref = strip(translate(prefix,' ','*'))
    else tpref = strip(translate(prefix))
  end

  parse value '0 0 0 0' with ssh_users tso_users other_users zosmf_users

  call Do_TSO
  drop stdate. date. datee.
  isfcols = null
  call Do_SSH
  drop stdate. date. datee.
  isfcols = null
  call Do_Other
  call get_ipl_info

  /* ----------------------- *
  | Now Generate our Report |
  * ----------------------- */
  c = 2
  dash_line = null
  r.1 = 'Interactive Users on' words(lpars) 'Systems -',
    'TSO:' tso_users ,
    'SSH:' ssh_users 'zOSMF:' zosmf_users
  if other_users > 0 then
  r.1 = r.1 'Other:' other_users
  r.2 = 'dash'
  dash_line = dash_line 2
  lpars = sortstr(lpars)
  do i = 1 to words(lpars)
    lpar = word(lpars,i)
    users = sortstr(users.lpar)
    c = c + 1
    r.c = 'System:  ' left(lpar,8) 'Users:' words(users) ,
      '   z/OS:' lpar.lpar
    do iu = 1 to words(users)
      c = c + 1
      uid = word(users,iu)
      Select
        When right(uid,1) = '>'
        then do
          sshflag = '(ssh)'
          name = subword(users.uid,1)
          tuid = left(uid,length(uid)-1)
        end
        When right(uid,1) = '*'
        then do
          sshflag = '(zOSMF)'
          name = subword(users.uid,1)
          tuid = left(uid,length(uid)-1)
        end
        Otherwise do
          sshflag = null
          tuid = uid
        end
      end
      if pos('.',tuid) > 0
      then parse value tuid with tuid'.' .
      r.c = left(tuid,9) users.uid  left(users.uid.dt,20) sshflag
    end
    c = c + 1
    r.c = 'dash'
    dash_line = dash_line c
  end
  r.0 = c
  len = 0
  do i = 1 to r.0
    if length(r.i) > len then len = length(r.i)
  end
  dash = copies('-',len)
  do i = 1 to words(dash_line)
    rl = word(dash_line,i)
    r.rl = dash
  end

  /* -------------------------- *
  | Report out based on option |
  * -------------------------- */
  if strip(option) = null then do
    do i = 1 to r.0
      say r.i
    end
    exit 0
  end
  if address() = 'SH' then option = '*'
  if option = 'B' then opt = 'Browse'
  if option = 'V' then opt = 'View'
  if option = 'Q' then do
    do i = 1 to r.0
      queue r.i
    end
    exit 0
  end

View_Stem:
  if option = '*' then do
    call syscalls 'ON'
    address 'SH'
    path = '/tmp/'userid()'.whos'
    address syscall
    'stat (path) s.'
    if s.0 > 0 then
    address 'SH' 'rm' path
    'open' path O_rdwr+0+O_creat+O_trunc 600
    fd = retval
    Address mvs 'execio * diskw' fd '(finis stem r.'
    address 'SH'
    'less' path
    'rm' path
  end
  else do
    Address TSO
    whosdd = 'whdd'random(9999)
    'Alloc f('whosdd') new spa(5,5) tr' ,
      'recfm(f b) lrecl(80) blksize(0)'
    'Execio * diskw' whosdd '(finis stem r.'
    Address ISPExec
    'lminit dataid(whosddb) ddname('whosdd')'
    opt 'dataid('whosddb')'
    'lmfree dataid('whosddb')'
    Address TSO
    'Free f('whosdd')'
  end
  Exit 0

Do_TSO:
  /* ------------------ *
  | Define our filters |
  * ------------------ */
  isfsysname = '*'
  isfowner = "*"
  isfprefix = tpref'*'
  isffilter = 'jobid t*'
  /* --------------- TSO ---------------- *
  | Extract the system names and userids |
  * ------------------------------------ */
  Address SDSF "ISFEXEC da"
  do i = 1 to jname.0
    lpar = sysname.i
    user = jname.i
    if zosmf_chk(procs.i) /= null then do
      user = user'*'
      zosmf_users = zosmf_users + 1
    end
    else tso_users = tso_users + 1
    if wordpos(lpar,lpars) = 0
    then lpars = lpars lpar
    users.lpar = users.lpar strip(user)
    if racflu = 1
    then users.user = left(get_user_name(user),20)
    else users.user = null
    users.user.dt = fix_date(word(stdate.i,1)) word(stdate.i,2)
  end
  Return

zosmf_chk:
  parse arg str
  if left(stepn.i,3) = 'IZU' then return 'IZU'
  return space(translate(str,' ',upper),0)

Do_SSH:
  /* --------------- SSH ---------------- *
  | Extract the system names and userids |
  * ------------------------------------ */
  isfprefix = '*'
  isfowner = tpref"*"
  isffilter = 'jname sshd*'
  Address SDSF "ISFEXEC ps"
  do i = 1 to jname.0
    if jobid.i /= null then iterate
    lpar = sysname.i
    user = ownerid.i
    if wordpos(lpar,lpars) = 0
    then lpars = lpars lpar
    user = strip(left(user'>',9))
    if wordpos(user,users.lpar) > 0 then iterate
    ssh_users = ssh_users + 1
    users.lpar = users.lpar user
    if racflu = 1
    then users.user = left(get_user_name(ownerid.i),20)
    else users.user = null
    users.user.dt = fix_date(datee.i) fix_timee(timee.i)
  end
  Return

Fix_Timee: procedure
  arg timee
  parse value timee with hh':'mm':'ss'.'.
  return right(hh+100,2)':'mm':'ss

Do_Other:
  /* ---------------------------------------------------- *
  | Add address space prefixes (e.g. XX* AB*) to process |
  | If blank then no other check will be performed.      |
  * ---------------------------------------------------- */
  if strip(other) = null then return
  do ispec = 1 to words(other)
    /* -------------- *
    | Define filters |
    * -------------- */
    isfsysname = ''
    isfowner = "*"
    isfdest = ' '
    isffilter = null
    isfprefix =  word(other,ispec)
    Address SDSF "ISFEXEC da"
    /* --------------------------------------------------- *
    | Now get the information on the other address spaces |
    * --------------------------------------------------- */
    do i = 1 to jname.0
      lpar = sysname.i
      user = jname.i
      userz = user || '.'i
      if wordpos(lpar,lpars) = 0
      then lpars = lpars lpar
      other_users = other_users + 1
      users.lpar = users.lpar strip(userz)
      users.userz.dt = fix_date(word(stdate.i,1)) word(stdate.i,2)
      ouser = get_other_user_name()
      users.userz = left(get_user_name(ouser),20)
    end
  end
  Return

  /* ------------------------ *
  | Display help information |
  * ------------------------ */
Do_Help:
  r.1 = 'WHOSON Syntax and Information.'
  r.2 = ' '
  r.3 = 'Syntax: %WHOSON option \ prefix-or-filter'
  r.4 = ' '
  r.5 = ' option may be: null    display on terminal'
  r.6 = '                B       use ISPF Browse'
  r.7 = '                V       use ISPF View'
  r.8 = '                Q       queue results in the TSO Stack'
  r.9 = '                ?       display this help information'
  r.10 = '    If running under the shell then any non-blank will'
  r.11 = '    use less to display the results.'
  r.12 = ' '
  r.13 = ' \ is a required separator (in case of a null option)'
  r.14 = ' '
  r.15 = ' prefix is a TSO User ID prefix to limit the report.'
  r.16 = '        e.g. SPL'
  r.17 = ' filter is a string to find in the userid.'
  r.18 = '        e.g. *L or L*'
  r.19 = ' '
  r.20 = 'Dependencies:   SDSF REXX'
  r.21 = '                RACF LU authority'
  r.22 = '                less (shell command)'
  r.0 = 22

  if address() = 'SH' then do
     option = '*'
     call view_stem
     end
  opt =  'Browse'
  if sysvar('sysispf') = 'ACTIVE'
  then if sysvar('sysenv') = 'FORE'
  then call view_stem
  do i = 1 to r.0
    say r.i
  end
  Exit 0

  /* --------------------------------- *
  | Extract the User's Name from RACF |
  * --------------------------------- */
Get_User_Name:
  arg uid .
  if right(uid,1) = '>'
  then  tuid = left(uid,length(uid)-1)
  else tuid = uid
  if pos('.',uid) > 0
  then parse value uid with uid'.' .
  if right(uid,1) = '*'
  then  tuid = left(uid,length(uid)-1)
  else tuid = uid
  call  outtrap 'uid.'
  Address TSO 'lu' tuid
  lurc = rc
  call outtrap 'off'
  if lurc > 4 then do
    racflu = 0
    name = null
    drop uid.
    return name
  end
  parse value uid.1 with .'NAME='name 'OWNER='.
  drop uid.
  return strip(cap1st(name))
  name = 'None'
  drop uid.
  return name

  /* ------------------------------------------------------ *
  | Get Other User by looking in the JOBs JESMSGLG for the |
  | ICH70001I message for the userid                       |
  * ------------------------------------------------------ */
Get_Other_User_Name:
  x = isfcalls('on')
  isfsysname = '*'
  isfowner = "*"
  isfprefix = '*'
  isfcols = null
  isffilter = 'JOBID EQ' jobid.i
  Address SDSF "ISFEXEC st (prefix st_"
  isfcols = null
  Address SDSF "ISFACT ST TOKEN('"st_TOKEN.1"') PARM(NP ?) (prefix j_"
  do id = 1 to j_dsname.0
    if right(j_dsname.id,9) /= '.JESMSGLG' then iterate
    Address SDSF "ISFBROWSE ST TOKEN('"j_token.id"') (verbose"
    do isfl = isfline.0 to 1 by -1
      if pos('ICH70001I',isfline.isfl) > 0 then do
        return word(isfline.isfl,4)
      end
    end
    return userid
  end
  x = isfcalls('off')
  return userid

  /* --------------------  rexx procedure  -------------------- *
  | Name:      SortStr                                         |
  |                                                            |
  | Function:  Sorts the provided string and returns it        |
  |                                                            |
  | Syntax:    string = sortstr(string)                        |
  |                                                            |
  | Usage:     Pass any string to SORTSTR and it will return   |
  |            the string sorted                               |
  |                                                            |
  | Author:    Lionel B. Dyck                                  |
  |                                                            |
  | History:  (most recent on top)                             |
  |            10/13/20 - Eliminate extra blank on last entry  |
  |            09/19/17 - Creation                             |
  |                                                            |
  * ---------------------------------------------------------- */
SortSTR: Procedure
  parse arg string
  do imx = 1 to words(string)-1
    do im = 1 to words(string)
      w1 = word(string,im)
      w2 = word(string,im+1)
      if w1 > w2 then do
        if im > 1
        then  lm = subword(string,1,im-1)
        else lm = ''
        rm = subword(string,im+2)
        string = lm strip(w2 w1) rm
      end
    end
  end
  return strip(string)

  /* ----------------------------------------------------- *
  | Name:  Cap1st                                         |
  |                                                       |
  | Function: Lowercase a string and then capitalize each |
  |           individual word.                            |
  |                                                       |
  | Syntax: x = cap1st(string)                            |
  |                                                       |
  | History:                                              |
  |           2024/01/31 Remove LC option (not needed)    |
  |           2021/12/14 Add exceptions                   |
  |           2021/11/29 Created by LBD                   |
  |                                                       |
  * ----------------------------------------------------- */
Cap1st: Procedure
  parse arg string
  reserved = 'DJC HSM'
  string = translate(string,"abcdefghijklmnopqrstuvwxyz",,
    "ABCDEFGHIJKLMNOPQRSTUVWXYZ")
  if pos(',',string) > 0
  then do
    string = translate(string,' ',',')
    first2last = 1
  end
  else first2last = 0
  len = words(string)
  do i = 1 to len
    w = word(string,i)
    if wordpos(translate(w),reserved) = 0 then do
      c = left(w,1)
      w = overlay(translate(c),w,1,1)
    end
    else do
      w = translate(w)
    end
    if i = 1
    then string = w subword(string,2)
    else do
      lw = subword(string,1,i-1)
      rw = subword(string,i+1)
      string = lw w rw
    end
  end
  if first2last = 1 then
  string = subword(string,2) word(string,1)
  return string

Get_IPL_Info: Procedure expose lpar.
  x = isfcalls('on')
  isfsysname = '*'
  isfowner = "*"
  Address SDSF 'ISFEXEC sys'
  do i = 1 to sysname.0
    parse value ipldate.i with date time
    parse value date with 3 year'.'days
    date = date('s',year||days,'j')
    date = left(date,4)'/'substr(date,5,2)'/'right(date,2)
    lparname = sysname.i
    lpar.lparname = subword(syslevel.i,2,1) 'IPL:' date time
  end
  x = isfcalls('off')
  return

Fix_Date: Procedure
  arg jdate
  parse value jdate with 3 yy'.'ddd
  jdate = yy || ddd
  base = date('B',jdate,'J')
  good = date('s',base,'b')
  parse value good with year 5 mm 7 dd
  return year'/'mm'/'dd
