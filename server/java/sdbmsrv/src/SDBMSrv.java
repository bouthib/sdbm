//***************************************************************************
//*                                                                         *
//* Copyright (c) 2008-2024 Benoit Bouthillier. All rights reserved.        *
//* Licensed under the MIT license.                                         *
//* See LICENSE file in the project root for full license information.      *
//*                                                                         *
//***************************************************************************
//*                                                                         *
//* Fichier :                                                               *
//*    SDBMSrv.java                                                         *
//*                                                                         *
//* Description :                                                           *
//*    Serveur SDBM                                                         *
//*                                                                         *
//***************************************************************************


import java.io.BufferedReader;
import java.io.FileReader;
import java.io.FileWriter;
import java.io.IOException;

import java.sql.CallableStatement;
import java.sql.Connection;
import java.sql.DriverManager;

import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;

import java.sql.Statement;
import java.sql.Timestamp;

import java.text.SimpleDateFormat;

import java.util.Enumeration;
import java.util.Locale;
import java.util.MissingResourceException;
import java.util.Properties;
import java.util.ResourceBundle;
import java.util.logging.FileHandler;
import java.util.logging.Level;
import java.util.logging.LogRecord;
import java.util.logging.SimpleFormatter;

import oracle.jdbc.OracleTypes;


public class SDBMSrv implements IApp
{

   //************************************************************************
   //* Variables globales                                                   *
   //************************************************************************

   // Identification
   private static final  String           pgmname = "SDBMSrv";
   private static final  String           schname = "SDBM";
   private static final  String           version = "0.16";

   // Journalisation
   private static final  SimpleDateFormat dateFormat = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss");
   private static final  SimpleDateFormat timeFormat = new SimpleDateFormat("HH:mm:ss");
   private static        FileHandler      logFile;
   private static        SDBMLogFormatter logFormatter;

   // Paramètres d'exécution
   private static        String           pSDBMSchema;
   private               String           pSDBMConnection;
   private               String           pSDBMUserName;
   private               String           pSDBMPassword;
   private               int              pSDBMSleepTime = 999;

   // Variables d'exécution
   private static final  String           sqlOracleStatus =

      "SELECT TO_CHAR(STARTUP_TIME,'YYYY-MM-DD HH24:MI:SS')                                                                                A_STARTUP_TIME"      +
      "      ,HOST_NAME                                                                                                                    A_NOM_SERVEUR"       +
      "      ,INSTANCE_NAME                                                                                                                A_NOM_INSTANCE"      +
      "      ,'ORA : ' || VERSION"                                                                                                                              +
      "                || ' ('"                                                                                                                                 +
      "                || (SELECT DECODE(INSTR(BANNER,' Edition')"                                                                                              +
      "                                 ,0,'Standard'"                                                                                                          +
      "                                 ,SUBSTR(BANNER"                                                                                                         +
      "                                        ,INSTR(SUBSTR(BANNER,1,INSTR(BANNER,' Edition')-1),' ',-1) + 1"                                                  +
      "                                        ,INSTR(BANNER,' Edition') - (INSTR(SUBSTR(BANNER,1,INSTR(BANNER,' Edition')-1),' ',-1) + 1)"                     +
      "                                        )"                                                                                                               +
      "                                 )"                                                                                                                      +
      "                           || ' Edition - '"                                                                                                             +
      "                           || DECODE(INSTR(BANNER,'bi'),0,'32 bits',SUBSTR(BANNER,INSTR(BANNER,'bi')-2,2) || ' bits')"                                   +
      "                      FROM V$VERSION"                                                                                                                    +
      "                     WHERE ROWNUM = 1"                                                                                                                   +
      "                   )"                                                                                                                                    +
      "                || ')'                                                                                                              A_VERSION"           +
      "      ,REPLACE(BACKGROUND_DUMP_DEST,'@',INSTANCE_NAME) || 'alert_' || INSTANCE_NAME || '.log'                                       A_FICHIER_ALERTE"    +
      "  FROM V$INSTANCE"                                                                                                                                       +
      "      ,(SELECT VALUE || DECODE((SELECT 1 FROM DUAL WHERE INSTR(VALUE,'\') > 0),1,'\','/') BACKGROUND_DUMP_DEST"                                          +
      "          FROM V$PARAMETER WHERE NAME = 'background_dump_dest')";

   private static final  String           sqlOracleBDP12C =

      "SELECT DII.VALUE || DECODE((SELECT 1 FROM DUAL WHERE INSTR(DII.VALUE,'\') > 0),1,'\','/') || 'alert_' || INSTANCE_NAME || '.log'    A_FICHIER_ALERTE"    +
      "       FROM V$DIAG_INFO DII"                                                                                                                             +
      "           ,V$INSTANCE  INS"                                                                                                                             +
      "      WHERE DII.NAME = 'Diag Trace'";

   private static final  String           sqlOracleVersion18c =

      "SELECT 'ORA : ' || VERSION_FULL"                                                                                                                         +
      "                || ' ('"                                                                                                                                 +
      "                || (SELECT DECODE(INSTR(BANNER,' Edition')"                                                                                              +
      "                                 ,0,'Standard'"                                                                                                          +
      "                                 ,SUBSTR(BANNER"                                                                                                         +
      "                                        ,INSTR(SUBSTR(BANNER,1,INSTR(BANNER,' Edition')-1),' ',-1) + 1"                                                  +
      "                                        ,INSTR(BANNER,' Edition') - (INSTR(SUBSTR(BANNER,1,INSTR(BANNER,' Edition')-1),' ',-1) + 1)"                     +
      "                                        )"                                                                                                               +
      "                                 )"                                                                                                                      +
      "                           || ' Edition - '"                                                                                                             +
      "                           || DECODE(INSTR(BANNER,'bi'),0,'64 bits',SUBSTR(BANNER,INSTR(BANNER,'bi')-2,2) || ' bits')"                                   +
      "                      FROM V$VERSION"                                                                                                                    +
      "                     WHERE ROWNUM = 1"                                                                                                                   +
      "                   )"                                                                                                                                    +
      "                || ')'                                                                                                              A_VERSION"           +
      "  FROM V$INSTANCE";

   private static final  String           sqlMSSQLServerStatus =

      " BEGIN"                                                                                                                                                        +
      "   DECLARE @ERRORLOG VARCHAR(255)"                                                                                                                             +
      "   DECLARE @REGKEY   VARCHAR(255)"                                                                                                                             +
      "   /* VERSION - SQL 2000 */"                                                                                                                                   +
      "   IF substring(CONVERT(varchar,ServerProperty('ProductVersion')),1,2) = '8.'"                                                                                 +
      "      /* DEFAULT instance */"                                                                                                                                  +
      "      IF CAST(ServerProperty('InstanceName') as varchar) = NULL"                                                                                               +
      "         SET @REGKEY = 'SOFTWARE\\Microsoft\\MSSQLServer\\MSSQLServer\\Parameters'"                                                                            +
      "      /* NAME instance */"                                                                                                                                     +
      "      ELSE"                                                                                                                                                    +
      "         SET @REGKEY = 'SOFTWARE\\Microsoft\\Microsoft SQL Server\\' + CAST(ServerProperty('InstanceName') as varchar) + '\\MSSQLServer\\Parameters'"          +
      "   ELSE"                                                                                                                                                       +
      "      BEGIN"                                                                                                                                                   +
      "         /* Finding MSSQLHOME */"                                                                                                                              +
      "         SELECT @REGKEY = 'SOFTWARE\\Microsoft\\Microsoft SQL Server\\'"                                                                                       +
      "                         + right(replace(name,'\\MSSQL\\Binn\\sqlservr.exe',''),charindex('\\', reverse(replace(name,'\\MSSQL\\Binn\\sqlservr.exe',''))) - 1)" +
      "                         + '\\MSSQLServer\\Parameters'"                                                                                                        +
      "           FROM sys.dm_os_loaded_modules"                                                                                                                      +
      "          WHERE name LIKE '%MSSQL\\Binn\\sqlservr.exe%'"                                                                                                       +
      "      END"                                                                                                                                                     +
      "   /* Finding the the SQL Server Log */"                                                                                                                       +
      "   EXECUTE master..xp_regread 'HKEY_LOCAL_MACHINE', @REGKEY, 'SQLArg1', @ERRORLOG OUTPUT"                                                                      +
      "   /* Checking if the -e is still there */"                                                                                                                    +
      "   IF substring(upper(@ERRORLOG),1,2) = '-E'"                                                                                                                  +
      "      SET @ERRORLOG = substring(upper(@ERRORLOG),3,100)"                                                                                                       +
      "   ELSE"                                                                                                                                                       +
      "      SET @ERRORLOG = 'N/A'"                                                                                                                                   +
      "   /* VERSION - SQL 2000 */"                                                                                                                                   +
      "   IF substring(CONVERT(varchar,ServerProperty('ProductVersion')),1,2) = '8.'"                                                                                 +
      "      SELECT CONVERT(varchar,login_time,120)                                                                                         AS A_STARTUP_TIME"        +
      "            ,CAST(ServerProperty('MachineName') as varchar)                                                                          AS A_NOM_SERVEUR"         +
      "            ,CAST(ServerProperty('InstanceName') as varchar)                                                                         AS A_NOM_INSTANCE"        +
      "            ,'SQL : ' + CONVERT(varchar,ServerProperty('ProductVersion')) + '.' + CONVERT(varchar,ServerProperty('ProductLevel'))"                             +
      "                      + ' (' + CONVERT(varchar,ServerProperty('Edition')) + ')'                                                      AS A_VERSION"             +
      "            ,@ERRORLOG                                                                                                               AS A_FICHIER_ALERTE"      +
      "        FROM (SELECT login_time"                                                                                                                               +
      "                FROM dbo.sysprocesses"                                                                                                                         +
      "               WHERE SPID = 1"                                                                                                                                 +
      "             ) SYP"                                                                                                                                            +
      "   ELSE"                                                                                                                                                       +
      "      SELECT CONVERT(varchar,login_time,120)                                                                                         AS A_STARTUP_TIME"        +
      "            ,CAST(ServerProperty('ComputerNamePhysicalNetBIOS') as varchar)                                                          AS A_NOM_SERVEUR"         +
      "            ,CAST(ServerProperty('InstanceName') as varchar)                                                                         AS A_NOM_INSTANCE"        +
      "            ,'SQL : ' + CONVERT(varchar,ServerProperty('ProductVersion')) + '.' + CONVERT(varchar,ServerProperty('ProductLevel'))"                             +
      "                      + ' (' + CONVERT(varchar,ServerProperty('Edition')) + ')'                                                      AS A_VERSION"             +
      "            ,@ERRORLOG                                                                                                               AS A_FICHIER_ALERTE"      +
      "        FROM (SELECT login_time"                                                                                                                               +
      "                FROM sys.sysprocesses"                                                                                                                         +
      "               WHERE SPID = 1"                                                                                                                                 +
      "             ) SYP"                                                                                                                                            +
      " END";

   private static final  String           sqlMYSQLServerStatusUptime =

   "SHOW GLOBAL STATUS WHERE VARIABLE_NAME = 'UPTIME'";

   private static final  String           sqlMYSQLServerStatusLogError =

   "SHOW GLOBAL VARIABLES WHERE VARIABLE_NAME = 'LOG_ERROR'";

   private static final  String           sqlMYSQLServerStatus =

   "SELECT DATE_SUB(NOW(),INTERVAL __UPTIME__ SECOND)  A_STARTUP_TIME"      +
   "      ,@@HOSTNAME                                  A_NOM_SERVEUR"       +
   "      ,'N/A'                                       A_NOM_INSTANCE"      +
   "      ,CONCAT('MSQ : ',VERSION())                  A_VERSION"           +
   "      ,'__LOG_ERROR__'                             A_FICHIER_ALERTE"    +
   ";";

   private static final  int              passBeforeGarbageCollection = 50;
   private static final  int              sleepTimeOnConnectionError  = 15;
   private               Connection       repositoryConnection;
   private               Connection       targetConnection;
   private               boolean          bStart = true;

   //
   // Variables statistique
   //
   private static final  int              statTimeBetweenDisplay = 900;
   private               long             statExTimeLastDisplay  = 0;

   // Boucle
   private               long             statDtTimeOfLonguestCompletedPass = -1;
   private               long             statExTimeOfLonguestCompletedPass = -1;

   // Connexion
   private               long             statDtTimeOfLonguestTargetConnection = -1;
   private               long             statExTimeOfLonguestTargetConnection = -1;
   private               String           statTargetOfLonguestTargetConnection = "";

   // Événement
   private               long             statDtTimeOfLonguestTargetEvent = -1;
   private               long             statExTimeOfLonguestTargetEvent = -1;
   private               String           statEventNOfLonguestTargetEvent = "";
   private               String           statTargetOfLonguestTargetEvent = "";

   // Réparation
   private               long             statDtTimeOfLonguestTargetRepair = -1;
   private               long             statExTimeOfLonguestTargetRepair = -1;
   private               String           statRepairOfLonguestTargetRepair = "";
   private               String           statEventNOfLonguestTargetRepair = "";
   private               String           statTargetOfLonguestTargetRepair = "";



   //************************************************************************
   //*                                                                      *
   //* Classe :                                                             *
   //*    SDBMLogFormatter                                                  *
   //*                                                                      *
   //************************************************************************
   private class SDBMLogFormatter extends SimpleFormatter
   {

      private SDBMLogFormatter()
      {
         super();
      }

      /**
       * @param logRecord
       * @return
       */
      public String format(LogRecord logRecord)
      {

         // Création d'un tampon
         StringBuffer stringBuffer = new StringBuffer();

         // Ajout de la date
         stringBuffer.append(dateFormat.format(logRecord.getMillis()));
         stringBuffer.append(" - ");

         // Ajout du niveau
         stringBuffer.append(String.format("%7s",logRecord.getLevel().getName().replaceAll("FINE","DEBUG")));
         stringBuffer.append(" : ");

         // Ajout du message formaté
         stringBuffer.append(formatMessage(logRecord));

         // Saut de ligne
         stringBuffer.append("\n");

         return stringBuffer.toString();
      }
   }



   //************************************************************************
   //*                                                                      *
   //* Méthode :                                                            *
   //*    writeLogMessage                                                   *
   //*                                                                      *
   //* Description :                                                        *
   //*    Envoi du message dans le journal de l'aplication.                 *
   //*                                                                      *
   //************************************************************************
   private void writeLogMessage(Level level, String message)
   {
      LogRecord  logRecord;

      logRecord = new LogRecord(level,message);
      logRecord.setLoggerName("");

      if (logFile != null)
         logFile.publish(logRecord);
      else
         System.out.println("LEVEL: " + level.getName() + ", MESSAGE: " + message);

      // Envoi du message à la base de données (best effort)
      if (repositoryConnection != null && logFile != null && level.intValue() >= logFile.getLevel().intValue())
      {
         CallableStatement sqlStmt;

         try
         {
            sqlStmt = repositoryConnection.prepareCall("{call " + pSDBMSchema + ".SDBM_BASE.JOURNALISER(?,?,?)}");

            // Préparation des paramètres
            sqlStmt.setString("A_SOURCE",pgmname);
            sqlStmt.setString("A_NIVEAU",level.getName().replaceAll("FINE","DEBUG"));
            sqlStmt.setString("A_TEXTE",message);

            // Exécution
            sqlStmt.execute();
            sqlStmt.close();
            sqlStmt = null;
         }
         catch (SQLException ex)
         {
            logRecord.setLevel(Level.WARNING);
            logRecord.setMessage("Unable to send log message to the SDBM repository.");
            logFile.publish(logRecord);
         }
      }

   }


   //************************************************************************
   //*                                                                      *
   //* Méthode :                                                            *
   //*    setLogMessageLevel                                                *
   //*                                                                      *
   //* Description :                                                        *
   //*    Ajustement du niveau de journalisation.                           *
   //*                                                                      *
   //************************************************************************
   private void setLogMessageLevel(String level)
   {
      if (!level.equalsIgnoreCase("NORMAL") && !level.equalsIgnoreCase("DEBUG"))
      {
         writeLogMessage(Level.WARNING,"Invalid value for logging level parameter (setLogMessageLevel). NORMAL logging level will be used.");
         logFile.setLevel(Level.CONFIG);
      }
      else
      {
         if (level.equalsIgnoreCase("DEBUG"))
         {
            if (logFile.getLevel() != Level.ALL)
            {
               writeLogMessage(Level.WARNING,"DEBUG logging level will be used. Performance will be impacted.");
               logFile.setLevel(Level.ALL);
            }
         }
         else
         {
            if (logFile.getLevel() != Level.CONFIG)
            {
               writeLogMessage(Level.CONFIG,"NORMAL logging level will be used.");
               logFile.setLevel(Level.CONFIG);
            }
         }
      }
   }


   //************************************************************************
   //*                                                                      *
   //* Méthode :                                                            *
   //*    writeHangCheckInfo                                                *
   //*                                                                      *
   //* Description :                                                        *
   //*    Mise à jour du fichier HangCheck.                                 *
   //*                                                                      *
   //************************************************************************
   private void writeHangCheckInfo(int nbSeconds, String statut)
   {
      FileWriter hcFile;

      try
      {
         hcFile = new FileWriter("log/" + pgmname + ".HangCheckInfo");
         hcFile.write(String.valueOf(System.currentTimeMillis() / 1000 + nbSeconds) + ":" + statut);
         hcFile.close();
      }
      catch (IOException ex)
      {
         writeLogMessage(Level.SEVERE, "Unable to write to " + pgmname + ".HangCheckInfo");
      }
   }


   //************************************************************************
   //*                                                                      *
   //* Méthode :                                                            *
   //*    sendStatusHangCheckInfo                                           *
   //*                                                                      *
   //* Description :                                                        *
   //*    Envoi du status relatif au fichier HangCheck.                     *
   //*                                                                      *
   //************************************************************************
   private void sendStatusHangCheckInfo()
   {
      BufferedReader brHCFile;
      String         hcData;

      try
      {
         brHCFile = new BufferedReader(new FileReader("log/" + pgmname + ".HangCheckInfo"));
         hcData = brHCFile.readLine();
         brHCFile.close();

         // Traitement du fichier vide...
         if (hcData == null)
         {
            hcData = "";
         }

         // Traitement de l'information
         if (hcData.contains(":--"))
         {
            writeLogMessage(Level.INFO, "The last shutdown was normal (hcData : " + hcData + ").");
         }
         else
         {
            writeLogMessage(Level.WARNING, "The last shutdown was not normal (hcData : " + hcData + "). The server was waiting on a target or have been restarted by the HangCheck mechanism. If this error occurs frequently, an investigation is required.");
         }
      }
      catch (IOException ex)
      {
         writeLogMessage(Level.WARNING, "Unable to read from " + pgmname + ".HangCheckInfo (the file is supposed to be automatically created).");
      }

   }


   //************************************************************************
   //*                                                                      *
   //* Méthode :                                                            *
   //*    wait                                                              *
   //*                                                                      *
   //* Description :                                                        *
   //*    Chargment du fichier de paramètre.                                *
   //*                                                                      *
   //************************************************************************
   private void wait(int seconds)
   {
      try
      {
         Thread.sleep(seconds * 1000);
      }
      catch (InterruptedException ex)
      {
         writeLogMessage(Level.SEVERE,ex.getMessage().replaceAll("\n"," : NL : "));
      }
   }


   //************************************************************************
   //*                                                                      *
   //* Méthode :                                                            *
   //*    setSleepTime                                                      *
   //*                                                                      *
   //* Description :                                                        *
   //*    Ajustement de la fréquence d'exécution.                           *
   //*                                                                      *
   //************************************************************************
   private void setSleepTime(int sleepTime)
   {
      if (sleepTime < 1 || sleepTime > 999)
      {
         pSDBMSleepTime = 60;
         writeLogMessage(Level.WARNING,"Invalid value for parameter sleepTime (setSleepTime). 60 seconds will be used.");
      }
      else
      {
         if (sleepTime != pSDBMSleepTime)
         {
            pSDBMSleepTime = sleepTime;
            writeLogMessage(Level.CONFIG,"The new value for parameter sleepTime is " + pSDBMSleepTime + " seconds.");
         }
      }
   }


   //************************************************************************
   //*                                                                      *
   //* Méthode :                                                            *
   //*    setLoginTimeout                                                   *
   //*                                                                      *
   //* Description :                                                        *
   //*    Ajustement de la fréquence d'exécution.                           *
   //*                                                                      *
   //************************************************************************
   private void setConnectionTimeout(int loginTimeout)
   {
      if (loginTimeout != 0 && (loginTimeout < 5 || loginTimeout > 999))
      {
         DriverManager.setLoginTimeout(0);
         writeLogMessage(Level.WARNING,"Invalid value for parameter connectionTimeout (setConnectionTimeout). 0 second (default) will be used.");
      }
      else
      {
         if (loginTimeout !=  DriverManager.getLoginTimeout())
         {
            DriverManager.setLoginTimeout(loginTimeout);
            writeLogMessage(Level.CONFIG,"The new value for parameter loginTimeout is " + loginTimeout + " second(s).");
         }
      }
   }


   //************************************************************************
   //*                                                                      *
   //* Méthode :                                                            *
   //*    loadParams                                                        *
   //*                                                                      *
   //* Description :                                                        *
   //*    Chargment du fichier de paramètre.                                *
   //*                                                                      *
   //************************************************************************
   private Properties loadParams(String file)
      throws IOException
   {
      Properties          prop;
      ResourceBundle      bundle;
      Enumeration<String> enume;
      String              key;

      prop = new Properties();
      bundle = ResourceBundle.getBundle(file);
      enume = bundle.getKeys();

      key = null;
      while(enume.hasMoreElements())
      {
         key = enume.nextElement();
         prop.put(key, bundle.getObject(key));
      }
      return prop;
   }


    //************************************************************************
    //*                                                                      *
    //* Méthode :                                                            *
    //*    setIdentifier                                                     *
    //*                                                                      *
    //* Description :                                                        *
    //*    Mise à jour de V$SESSION.CLIENT_IDENTIFIER.                       *
    //*                                                                      *
    //************************************************************************
    private void setIdentifier(String message)
    {
       // Envoi du message à la base de données (best effort)
       if (repositoryConnection != null)
       {
          CallableStatement sqlStmt;

          try
          {
             sqlStmt = repositoryConnection.prepareCall("{call DBMS_SESSION.SET_IDENTIFIER(?)}");

             // Préparation des paramètres
             sqlStmt.setString("CLIENT_ID",message);

             // Exécution
             sqlStmt.execute();
             sqlStmt.close();
             sqlStmt = null;
          }
          catch (SQLException ex)
          {
             writeLogMessage(Level.WARNING,"Unable to send identifier (DBMS_SESSION) to SDBM repository (" + ex.getMessage().replaceAll("\n"," : NL : ") + ").");
          }
       }
    }


   //************************************************************************
   //*                                                                      *
   //* Méthode :                                                            *
   //*    connectToRepository                                               *
   //*                                                                      *
   //* Description :                                                        *
   //*    Effectue une connection au référentiel SDBM.                      *
   //*                                                                      *
   //************************************************************************
   private void connectToRepository()
   {
      boolean validConnection = false;

      if (repositoryConnection != null)
      {
         try
         {
            repositoryConnection.rollback();
            validConnection = true;
         }
         catch (SQLException ex)
         {
            writeLogMessage(Level.WARNING,"Failed validation of repository connection : rollback (" + ex.getMessage().replaceAll("\n"," : NL : ") + ").");
            repositoryConnection = null;
         }
      }

      while (!validConnection)
      {
         try
         {
            // Connect to SDBM repository
            writeLogMessage(Level.INFO,"Trying to connect to SDBM repository (" + pSDBMConnection + ")...");
            repositoryConnection = DriverManager.getConnection("jdbc:oracle:thin:@" + pSDBMConnection,pSDBMUserName,pSDBMPassword);
            repositoryConnection.setAutoCommit(false);
            writeLogMessage(Level.INFO,"Connected to SDBM repository.");
            validConnection = true;
         }
         catch (SQLException ex)
         {
            writeLogMessage(Level.SEVERE,"Unable to connect to SDBM repository (" + ex.getMessage().replaceAll("\n"," : NL : ") + ").");
            writeLogMessage(Level.INFO,"Waiting " + sleepTimeOnConnectionError + " seconds before trying again...");
            wait(sleepTimeOnConnectionError);
         }
      }
   }


   //************************************************************************
   //*                                                                      *
   //* Méthode :                                                            *
   //*    statDisplay                                                       *
   //*                                                                      *
   //* Description :                                                        *
   //*    Affichage des statistiques et remise à zéro si la période est     *
   //*    atteinte.                                                         *
   //*                                                                      *
   //************************************************************************
   private void statDisplay()
   {
      if ((System.currentTimeMillis() - statExTimeLastDisplay) / 1000 >=  statTimeBetweenDisplay)
      {
         //
         // Affichage des valeur
         //
         writeLogMessage(Level.INFO,"Begin of dump of " + pgmname + " system statistics...");
         writeLogMessage(Level.INFO,"Java memory in use : " + (Runtime.getRuntime().totalMemory() - Runtime.getRuntime().freeMemory()) + " bytes.");

         if (statExTimeOfLonguestCompletedPass != -1)
            writeLogMessage(Level.INFO,"The longuest completed pass for the period took " + statExTimeOfLonguestCompletedPass / 1000 + "." + statExTimeOfLonguestCompletedPass % 1000 + " seconds. It occurs at " + timeFormat.format(statDtTimeOfLonguestCompletedPass) + ".");

         if (statExTimeOfLonguestTargetConnection != -1)
            writeLogMessage(Level.INFO,"The longuest connection for the period took " + statExTimeOfLonguestTargetConnection + " milliseconds. It occurs at " + timeFormat.format(statDtTimeOfLonguestTargetConnection) + " while connecting to " + statTargetOfLonguestTargetConnection + ".");

         if (statExTimeOfLonguestTargetEvent != -1)
            writeLogMessage(Level.INFO,"The longuest event execution for the period took " + statExTimeOfLonguestTargetEvent + " milliseconds. It occurs at " + timeFormat.format(statDtTimeOfLonguestTargetEvent) + " while executing event " + statEventNOfLonguestTargetEvent + " on target " + statTargetOfLonguestTargetEvent + ".");

         if (statExTimeOfLonguestTargetRepair != -1)
            writeLogMessage(Level.INFO,"The longuest repair execution for the period took " + statExTimeOfLonguestTargetRepair + " milliseconds. It occurs at " + timeFormat.format(statDtTimeOfLonguestTargetRepair) + " while executing repair " + statRepairOfLonguestTargetRepair + " for event " + statEventNOfLonguestTargetRepair + " on target " + statTargetOfLonguestTargetRepair + ".");

         writeLogMessage(Level.INFO,"End of dump of " + pgmname + " system statistics.");

         //
         // Remise à zéro des compteurs
         //
         statExTimeLastDisplay = System.currentTimeMillis();

         // Boucle
         statDtTimeOfLonguestCompletedPass = -1;
         statExTimeOfLonguestCompletedPass = -1;

         // Connexion
         statDtTimeOfLonguestTargetConnection = -1;
         statExTimeOfLonguestTargetConnection = -1;
         statTargetOfLonguestTargetConnection = "";

         // Événement
         statDtTimeOfLonguestTargetEvent = -1;
         statExTimeOfLonguestTargetEvent = -1;
         statEventNOfLonguestTargetEvent = "";
         statTargetOfLonguestTargetEvent = "";

         // Réparation
         statDtTimeOfLonguestTargetRepair = -1;
         statExTimeOfLonguestTargetRepair = -1;
         statRepairOfLonguestTargetRepair = "";
         statEventNOfLonguestTargetRepair = "";
         statTargetOfLonguestTargetRepair = "";
      }
   }


   //************************************************************************
   //*                                                                      *
   //* Méthode :                                                            *
   //*    statSaveTargetRepair                                              *
   //*                                                                      *
   //* Description :                                                        *
   //*    Sauvegarde des statistiques de réparations (si il y a lieu).      *
   //*                                                                      *
   //************************************************************************
   private void statSaveTargetRepair(String repairName, String eventName, String targetName, long executionTime)
   {
      if (executionTime > statExTimeOfLonguestTargetRepair)
      {
         statDtTimeOfLonguestTargetRepair = System.currentTimeMillis();
         statExTimeOfLonguestTargetRepair = executionTime;
         statRepairOfLonguestTargetRepair = repairName;
         statEventNOfLonguestTargetRepair = eventName;
         statTargetOfLonguestTargetRepair = targetName;
      }
   }


   //************************************************************************
   //*                                                                      *
   //* Méthode :                                                            *
   //*    statSaveTargetEvent                                               *
   //*                                                                      *
   //* Description :                                                        *
   //*    Sauvegarde des statistiques d'événements (si il y a lieu).        *
   //*                                                                      *
   //************************************************************************
   private void statSaveTargetEvent(String eventName, String targetName, long executionTime)
   {
      if (executionTime > statExTimeOfLonguestTargetEvent)
      {
         statDtTimeOfLonguestTargetEvent = System.currentTimeMillis();
         statExTimeOfLonguestTargetEvent = executionTime;
         statEventNOfLonguestTargetEvent = eventName;
         statTargetOfLonguestTargetEvent = targetName;
      }
   }


   //************************************************************************
   //*                                                                      *
   //* Méthode :                                                            *
   //*    statSaveTargetConnection                                          *
   //*                                                                      *
   //* Description :                                                        *
   //*    Sauvegarde des statistiques de connexions (si il y a lieu).       *
   //*                                                                      *
   //************************************************************************
   private void statSaveTargetConnection(String targetName, long executionTime)
   {
      if (executionTime > statExTimeOfLonguestTargetConnection)
      {
         statDtTimeOfLonguestTargetConnection = System.currentTimeMillis();
         statExTimeOfLonguestTargetConnection = executionTime;
         statTargetOfLonguestTargetConnection = targetName;
      }
   }


   //************************************************************************
   //*                                                                      *
   //* Méthode :                                                            *
   //*    statSaveCompletedPass                                             *
   //*                                                                      *
   //* Description :                                                        *
   //*    Sauvegarde des statistiques de boucle (si il y a lieu).           *
   //*                                                                      *
   //************************************************************************
   private void statSaveCompletedPass(long executionTime)
   {
      if (executionTime > statExTimeOfLonguestCompletedPass)
      {
         statDtTimeOfLonguestCompletedPass = System.currentTimeMillis();
         statExTimeOfLonguestCompletedPass = executionTime;
      }
   }


   //************************************************************************
   //*                                                                      *
   //* Méthode :                                                            *
   //*    monitorRepairs                                                    *
   //*                                                                      *
   //* Description :                                                        *
   //*    Traitement de monitoring des événements.                          *
   //*                                                                      *
   //************************************************************************
   private void monitorRepairs(String targetName)
   {
      CallableStatement sqlStmtRepairList;
      CallableStatement sqlStmtRepairStatus;
      Statement         sqlStmtRepair = null;

      ResultSet         sqlResultsetRepairList = null;

      long              statStart;
      boolean           monitorError;

      try
      {
         sqlStmtRepairList   = repositoryConnection.prepareCall("{call " + pSDBMSchema + ".SDBM_BASE.TRAITEMENT_REPARATIONS_BD(?,?)}");
         sqlStmtRepairStatus = repositoryConnection.prepareCall("{call " + pSDBMSchema + ".SDBM_BASE.SAUVEGARDE_REPARATION_BD(?,?,?,?)}");

         // Enregistrement des paramètres
         sqlStmtRepairList.setString("A_NOM_CIBLE",targetName);
         sqlStmtRepairList.registerOutParameter("A_CUR_INFO", OracleTypes.CURSOR);

         // Exécution
         sqlStmtRepairList.execute();

         // Réception de la liste des cibles à traiter
         sqlResultsetRepairList = (ResultSet)sqlStmtRepairList.getObject("A_CUR_INFO");

         // Traitement des réparations
         while (sqlResultsetRepairList.next())
         {
            // Remise à zéro de l'indicateur d'erreur
            monitorError = false;

            //
            // Exécution d'une réparation
            //

            try
            {
               statStart = System.currentTimeMillis();
               writeLogMessage(Level.FINE,"Repair work that will be processed for event " + sqlResultsetRepairList.getString("NOM_EVENEMENT") + ", target " + targetName + " is : " + sqlResultsetRepairList.getString("NOM_REPARATION") + ".");
               writeLogMessage(Level.FINE,"SQL command :\n***\n" + sqlResultsetRepairList.getString("COMMANDE") + "\n***");

               setIdentifier(targetName + "." + sqlResultsetRepairList.getString("NOM_EVENEMENT") + "." + sqlResultsetRepairList.getString("NOM_REPARATION"));
               writeHangCheckInfo(300,targetName + "." + sqlResultsetRepairList.getString("NOM_EVENEMENT") + "." + sqlResultsetRepairList.getString("NOM_REPARATION"));

               sqlStmtRepair = targetConnection.createStatement();
               sqlStmtRepair.execute(sqlResultsetRepairList.getString("COMMANDE").replaceAll("\r"," ").replaceAll("\n"," "));
               statSaveTargetRepair(sqlResultsetRepairList.getString("NOM_REPARATION"), sqlResultsetRepairList.getString("NOM_EVENEMENT"), targetName, (System.currentTimeMillis() - statStart));
            }
            catch (SQLException ex)
            {
               // Échec de l'exécution de l'événement
               monitorError = true;
               writeLogMessage(Level.WARNING,"Repair work " + sqlResultsetRepairList.getString("NOM_REPARATION") + ", event " + sqlResultsetRepairList.getString("NOM_EVENEMENT") + ", target " + targetName + " failed (" + ex.getMessage().replaceAll("\n"," : NL : ") + ").");
               writeLogMessage(Level.WARNING,"SQL command was :\n***\n" + sqlResultsetRepairList.getString("COMMANDE") + "\n***");
            }
            finally
            {
               if (sqlStmtRepair != null) { try { sqlStmtRepair.close(); sqlStmtRepair = null; } catch (Exception ex) { writeLogMessage(Level.WARNING,"Error while releasing SQL statement sqlStmtRepair."); }};
            }

            //
            // Enregistrement du résultat de l'exécution d'une réparation
            //
            try
            {
               // Enregistrement du statut de l'événement - Préparation des paramètres
               sqlStmtRepairStatus.setString("A_NOM_CIBLE",targetName);
               sqlStmtRepairStatus.setString("A_NOM_EVENEMENT",sqlResultsetRepairList.getString("NOM_EVENEMENT"));
               sqlStmtRepairStatus.setString("A_NOM_REPARATION",sqlResultsetRepairList.getString("NOM_REPARATION"));

               if (monitorError)
                  sqlStmtRepairStatus.setString("A_STATUT","ER");
               else
                  sqlStmtRepairStatus.setString("A_STATUT","OK");

               // Exécution
               sqlStmtRepairStatus.execute();
            }
            catch (SQLException ex)
            {
               monitorError = true;
               writeLogMessage(Level.WARNING,"Unable to send the repair work status to SDBM repository for repair work " + sqlResultsetRepairList.getString("NOM_REPARATION") + ", event " + sqlResultsetRepairList.getString("NOM_EVENEMENT") + ", target " + targetName + " failed (" + ex.getMessage().replaceAll("\n"," : NL : ") + ").");
            }

         }
         // Fin de l'instruction while

         //
         // Libération des ressources (cible)
         //
         try
         {
            // Si erreur
            if (sqlStmtRepairStatus != null)
                sqlStmtRepairStatus.close();
            sqlStmtRepairStatus = null;
         }
         catch (SQLException ex)
         {
            writeLogMessage(Level.WARNING,"Error while releasing target resources for repair work " + sqlResultsetRepairList.getString("NOM_REPARATION") + ", event " + sqlResultsetRepairList.getString("NOM_EVENEMENT") + ", target " + targetName + " failed (" + ex.getMessage().replaceAll("\n"," : NL : ") + ").");
         }

         //
         // Libération des ressources (référentiel)
         //
         try
         {
            sqlResultsetRepairList.close();
            sqlResultsetRepairList = null;

            sqlStmtRepairList.close();
            sqlStmtRepairList = null;
         }
         catch (SQLException ex)
         {
            writeLogMessage(Level.WARNING,"Error while releasing repository resources for monitorRepairs.");
         }
      }
      catch (SQLException ex)
      {
         writeLogMessage(Level.SEVERE,"Unable to get the event list (" + ex.getMessage().replaceAll("\n"," : NL : ") + ").");
      }
   }


   //************************************************************************
   //*                                                                      *
   //* Méthode :                                                            *
   //*    monitorEvents                                                     *
   //*                                                                      *
   //* Description :                                                        *
   //*    Traitement de monitoring des événements.                          *
   //*                                                                      *
   //************************************************************************
   private void monitorEvents(String targetName, String sousTypeCible)
   {
      CallableStatement sqlStmtEventList;
      CallableStatement sqlStmtEventStatus;
      PreparedStatement prepSqlStmt = null;

      ResultSet         sqlResultsetEventList   = null;
      ResultSet         sqlResultsetEventReturn = null;

      long              statStart;
      boolean           emptyCursor;
      boolean           monitorError;

      try
      {
         sqlStmtEventList   = repositoryConnection.prepareCall("{call " + pSDBMSchema + ".SDBM_BASE.TRAITEMENT_EVENEMENTS_BD(?,?)}");
         sqlStmtEventStatus = repositoryConnection.prepareCall("{call " + pSDBMSchema + ".SDBM_BASE.SAUVEGARDE_STATUT_EVENEMENT_BD(?,?,?,?)}");

         // Enregistrement des paramètres
         sqlStmtEventList.setString("A_NOM_CIBLE",targetName);
         sqlStmtEventList.registerOutParameter("A_CUR_INFO", OracleTypes.CURSOR);

         // Exécution
         sqlStmtEventList.execute();

         // Réception de la liste des événements à traiter
         sqlResultsetEventList = (ResultSet)sqlStmtEventList.getObject("A_CUR_INFO");

         // Traitement des événements
         while (sqlResultsetEventList.next())
         {
            // Remise à zéro de l'indicateur d'erreur
            monitorError = false;

            //
            // Exécution d'un événement
            //
            try
            {
               statStart = System.currentTimeMillis();
               writeLogMessage(Level.FINE,"Event that will be processed is : " + sqlResultsetEventList.getString("NOM_EVENEMENT") + " (timeout in effect will be " + sqlResultsetEventList.getInt("DELAI_MAX_EXEC_SEC") + " seconds)...");
               writeLogMessage(Level.FINE,"SQL command :\n***\n" + sqlResultsetEventList.getString("COMMANDE") + "\n***");

               setIdentifier(targetName + "." + sqlResultsetEventList.getString("NOM_EVENEMENT"));
               writeHangCheckInfo(sqlResultsetEventList.getInt("DELAI_MAX_EXEC_SEC"),targetName + "." + sqlResultsetEventList.getString("NOM_EVENEMENT"));

               prepSqlStmt = targetConnection.prepareStatement(sqlResultsetEventList.getString("COMMANDE"));
               prepSqlStmt.setQueryTimeout(sqlResultsetEventList.getInt("DELAI_MAX_EXEC_SEC"));

               // Traitement MySQL (traitement des résultats multiple / recherche du dernier résultats)
               if (sousTypeCible.contentEquals("MY"))
               {
                  boolean bMoreResultSets = prepSqlStmt.execute();
                  while (bMoreResultSets || prepSqlStmt.getUpdateCount() != -1)
                  {
                     if (bMoreResultSets)
                     {
                         sqlResultsetEventReturn = prepSqlStmt.getResultSet();
                     }

                     // On cherche le résultats suivant (si il exsite)
                     bMoreResultSets = prepSqlStmt.getMoreResults(Statement.KEEP_CURRENT_RESULT);
                  }
               }
               else
               {
                  sqlResultsetEventReturn = prepSqlStmt.executeQuery();
               }

               // Validation des résultats (doit-être 2 colonnes, type String)
               if (
                         (sqlResultsetEventReturn == null)
                     ||  (sqlResultsetEventReturn.getMetaData().getColumnCount() != 2)
                     || !(sqlResultsetEventReturn.getMetaData().getColumnTypeName(1).toUpperCase().contains("CHAR"))
                     || !(sqlResultsetEventReturn.getMetaData().getColumnTypeName(2).toUpperCase().contains("CHAR"))
                  )
               {
                  monitorError = true;
                  writeLogMessage(Level.WARNING,"SQL statement for event " + sqlResultsetEventList.getString("NOM_EVENEMENT") + " (target " + targetName + ") is invalid (must return 2 columns of datatype [N][VAR]CHAR[2].");
                  if (!(sqlResultsetEventReturn.getMetaData().getColumnCount() != 2))
                     writeLogMessage(Level.WARNING,"Datatype of column 1 is : " + sqlResultsetEventReturn.getMetaData().getColumnTypeName(1) + ", column 2 is : " + sqlResultsetEventReturn.getMetaData().getColumnTypeName(2));
               }
               statSaveTargetEvent(sqlResultsetEventList.getString("NOM_EVENEMENT"), targetName, (System.currentTimeMillis() - statStart));
            }
            catch (SQLException ex)
            {
               // Échec de l'exécution de l'événement
               monitorError = true;
               writeLogMessage(Level.WARNING,"Unable to process event " + sqlResultsetEventList.getString("NOM_EVENEMENT") + ", target " + targetName + " (" + ex.getMessage().replaceAll("\n"," : NL : ") + ").");
               writeLogMessage(Level.WARNING,"SQL command was :\n***\n" + sqlResultsetEventList.getString("COMMANDE") + "\n***");
            }

            //
            // Enregistrement du résultat d'un événement
            //
            if (!monitorError)
            {
               try
               {
                  emptyCursor = true;
                  writeLogMessage(Level.FINE,"Begin of return event(s) :");
                  while (sqlResultsetEventReturn.next())
                  {
                     emptyCursor = false;
                     writeLogMessage(Level.FINE,"*" + sqlResultsetEventReturn.getString(1) + "* : *" + sqlResultsetEventReturn.getString(2) + "*");

                     // Enregistrement du statut de l'événement - Préparation des paramètres
                     sqlStmtEventStatus.setString("A_NOM_CIBLE",targetName);
                     sqlStmtEventStatus.setString("A_NOM_EVENEMENT",sqlResultsetEventList.getString("NOM_EVENEMENT"));
                     sqlStmtEventStatus.setString("A_NOM_OBJET",sqlResultsetEventReturn.getString(1));
                     sqlStmtEventStatus.setString("A_RESULTAT",sqlResultsetEventReturn.getString(2));

                     // Exécution
                     sqlStmtEventStatus.execute();
                  }
                  // Fin while
                  writeLogMessage(Level.FINE,"End of return event(s).");

                  // Vérification pour situation normale
                  if (emptyCursor)
                  {
                     // Enregistrement du statut de l'événement - Préparation des paramètres
                     sqlStmtEventStatus.setString("A_NOM_CIBLE",targetName);
                     sqlStmtEventStatus.setString("A_NOM_EVENEMENT",sqlResultsetEventList.getString("NOM_EVENEMENT"));
                     sqlStmtEventStatus.setString("A_NOM_OBJET","?");
                     sqlStmtEventStatus.setString("A_RESULTAT","?");

                     // Exécution
                     sqlStmtEventStatus.execute();
                  }

                  // Libération des ressources - base de données cible
                  sqlResultsetEventReturn.close();
                  sqlResultsetEventReturn = null;

                  prepSqlStmt.close();
                  prepSqlStmt = null;
               }
               catch (SQLException ex)
               {
                  monitorError = true;
                  writeLogMessage(Level.SEVERE,"Unable to send the event status to SDBM repository for event " + sqlResultsetEventList.getString("NOM_EVENEMENT") + ", target " + targetName + " (" + ex.getMessage().replaceAll("\n"," : NL : ") + ").");
               }
            }

            //
            // Libération des ressources (cible)
            //
            try
            {
               // Si erreur
               if (sqlResultsetEventReturn != null)
                  sqlResultsetEventReturn.close();
               sqlResultsetEventReturn = null;

               // Si erreur
               if (prepSqlStmt != null)
                   prepSqlStmt.close();
               prepSqlStmt = null;
            }
            catch (SQLException ex)
            {
               writeLogMessage(Level.WARNING,"Error while releasing resources from target database " + sqlResultsetEventList.getString("NOM_CIBLE") + " - monitorEvents (" + ex.getMessage().replaceAll("\n"," : NL : ") + ").");
            }

         }
         // Fin de l'instruction while

         //
         // Libération des ressources (référentiel)
         //
         try
         {
            sqlResultsetEventList.close();
            sqlResultsetEventList = null;

            sqlStmtEventStatus.close();
            sqlStmtEventStatus = null;

            sqlStmtEventList.close();
            sqlStmtEventList = null;
         }
         catch (SQLException ex)
         {
            writeLogMessage(Level.WARNING,"Error while releasing repository resources for monitorEvents.");
         }
      }
      catch (SQLException ex)
      {
         writeLogMessage(Level.SEVERE,"Unable to get the event list (" + ex.getMessage().replaceAll("\n"," : NL : ") + ").");
      }
   }


   //************************************************************************
   //*                                                                      *
   //* Méthode :                                                            *
   //*    monitor                                                           *
   //*                                                                      *
   //* Description :                                                        *
   //*    Traitement de monitoring pricipal.                                *
   //*                                                                      *
   //************************************************************************
   private void monitor()
   {
      //
      //
      // Connect to SDBM repository
      //
      //
      connectToRepository();

      // Envoi de l'information sur le dernier arrêt (si nous sommes en mode démarrage)
      if (bStart)
      {
         sendStatusHangCheckInfo();
         bStart = false;
      }

      //
      //
      // Traitement des cibles
      //
      //
      CallableStatement sqlStmtTargetList;
      CallableStatement sqlStmtTargetStatusUP;
      CallableStatement sqlStmtTargetStatusDN;
      CallableStatement sqlStmtEventReturnHandling;
      PreparedStatement prepSqlStmt = null;

      ResultSet         sqlResultsetTargetList         = null;
      ResultSet         sqlResultsetDatabaseStatus     = null;
      ResultSet         sqlResultsetDatabaseStatusAlt  = null;
      ResultSet         sqlResultsetDatabaseVersionAlt = null;
      int               oraVersion                     = 0;

      Properties        infoOracle;

      long              statStart = 0;
      boolean           monitorError;
      String            sqlDatabaseStatus = null;

      try
      {
         // Préparation des appels (obtenir la liste / enregistrement des statuts)
         sqlStmtTargetList          = repositoryConnection.prepareCall("{call " + pSDBMSchema + ".SDBM_BASE.TRAITEMENT_CIBLES_BD(?,?,?,?,?)}");
         sqlStmtTargetStatusUP      = repositoryConnection.prepareCall("{call " + pSDBMSchema + ".SDBM_BASE.SAUVEGARDE_STATUT_CIBLE(?,?,?,?,?,?,?,?)}");
         sqlStmtTargetStatusDN      = repositoryConnection.prepareCall("{call " + pSDBMSchema + ".SDBM_BASE.SAUVEGARDE_STATUT_CIBLE(?,?,?)}");
         sqlStmtEventReturnHandling = repositoryConnection.prepareCall("{call " + pSDBMSchema + ".SDBM_BASE.TRAITER_STATUT_EVENEMENT_BD(?)}");

         // Enregistrement des paramètres
         sqlStmtTargetList.setString("A_VERSION_SERVEUR",version);
         sqlStmtTargetList.registerOutParameter("A_CUR_INFO", OracleTypes.CURSOR);
         sqlStmtTargetList.registerOutParameter("A_DELAI_MAX_CONNEXION_SEC", OracleTypes.INTEGER);
         sqlStmtTargetList.registerOutParameter("A_FREQU_VERIF_CIBLE_SEC", OracleTypes.INTEGER);
         sqlStmtTargetList.registerOutParameter("A_NIVEAU_JOURNAL_SERVEUR", OracleTypes.VARCHAR);

         // Exécution
         sqlStmtTargetList.execute();

         // Réception de la liste des cibles à traiter
         sqlResultsetTargetList = (ResultSet)sqlStmtTargetList.getObject("A_CUR_INFO");

         // Réception du délai max. de connexion
         setConnectionTimeout(sqlStmtTargetList.getInt("A_DELAI_MAX_CONNEXION_SEC"));

         // Réception du délai de vérification
         setSleepTime(sqlStmtTargetList.getInt("A_FREQU_VERIF_CIBLE_SEC"));

         // Réception du niveau de journalisation
         setLogMessageLevel(sqlStmtTargetList.getString("A_NIVEAU_JOURNAL_SERVEUR"));

         // Traitement des cibles
         infoOracle = new Properties();
         while (sqlResultsetTargetList.next())
         {
            // Remise à zéro de l'indicateur d'erreur
            monitorError = false;

            //
            // Connexion à la base de données cible
            //
            try
            {
               statStart = System.currentTimeMillis();
               writeLogMessage(Level.FINE,"Trying to connect to " + sqlResultsetTargetList.getString("NOM_CIBLE") + "...");
               setIdentifier(sqlResultsetTargetList.getString("NOM_CIBLE"));
               writeHangCheckInfo(sqlStmtTargetList.getInt("A_DELAI_MAX_CONNEXION_SEC"),sqlResultsetTargetList.getString("NOM_CIBLE"));

               if (sqlResultsetTargetList.getString("SOUS_TYPE_CIBLE").contentEquals("OR"))
               {
                  infoOracle.clear();
                  infoOracle.put("user", sqlResultsetTargetList.getString("NOM_USAGER"));
                  infoOracle.put("password", sqlResultsetTargetList.getString("MOT_PASSE"));

                  // Si la connexion doit être (SYSOPER ou SYSDBA)
                  if (sqlResultsetTargetList.getString("TYPE_CONNEXION").contentEquals("SD"))
                  {
                     infoOracle.put("internal_logon","sysdba");
                  }

                  try
                  {
                     targetConnection = DriverManager.getConnection("jdbc:oracle:thin:@" + sqlResultsetTargetList.getString("CONNEXION"),infoOracle);
                  }
                  catch (SQLException exTargetConnection)
                  {
                     if (exTargetConnection.getMessage().contentEquals("Io exception: Got minus one from a read call"))
                     {
                        // Deuxième essai si l'erreur est : Io exception: Got minus one from a read call
                        writeLogMessage(Level.INFO,"Unable to connect to " + sqlResultsetTargetList.getString("NOM_CIBLE") + " (" + exTargetConnection.getMessage().replaceAll("\n"," : NL : ") + "). Will try again...");
                        targetConnection = DriverManager.getConnection("jdbc:oracle:thin:@" + sqlResultsetTargetList.getString("CONNEXION"),infoOracle);
                     }
                     else
                     {
                        throw exTargetConnection;
                     }

                  }

                  sqlDatabaseStatus = sqlOracleStatus;

               }

               else if (sqlResultsetTargetList.getString("SOUS_TYPE_CIBLE").contentEquals("MS"))
               {
                  try
                  {
                     targetConnection = DriverManager.getConnection("jdbc:sqlserver:" + sqlResultsetTargetList.getString("CONNEXION"),sqlResultsetTargetList.getString("NOM_USAGER"),sqlResultsetTargetList.getString("MOT_PASSE"));
                     targetConnection.setTransactionIsolation(Connection.TRANSACTION_READ_UNCOMMITTED);
                  }
                  catch (SQLException exTargetConnection)
                  {
                     if (exTargetConnection.getMessage().contentEquals("Io exception: Got minus one from a read call"))
                     {
                        // Deuxième essai si l'erreur est : Io exception: Got minus one from a read call
                        writeLogMessage(Level.INFO,"Unable to connect to " + sqlResultsetTargetList.getString("NOM_CIBLE") + " (" + exTargetConnection.getMessage().replaceAll("\n"," : NL : ") + "). Will try again...");
                        targetConnection = DriverManager.getConnection("jdbc:sqlserver:" + sqlResultsetTargetList.getString("CONNEXION"),sqlResultsetTargetList.getString("NOM_USAGER"),sqlResultsetTargetList.getString("MOT_PASSE"));
                        targetConnection.setTransactionIsolation(Connection.TRANSACTION_READ_UNCOMMITTED);
                     }
                     else
                     {
                        throw exTargetConnection;
                     }

                  }

                  sqlDatabaseStatus = sqlMSSQLServerStatus;
               }

               else if (sqlResultsetTargetList.getString("SOUS_TYPE_CIBLE").contentEquals("MY"))
               {
                  try
                  {
                     targetConnection = DriverManager.getConnection("jdbc:mysql:" + sqlResultsetTargetList.getString("CONNEXION") + "/INFORMATION_SCHEMA?allowMultiQueries=true",sqlResultsetTargetList.getString("NOM_USAGER"),sqlResultsetTargetList.getString("MOT_PASSE"));
                     targetConnection.setTransactionIsolation(Connection.TRANSACTION_READ_UNCOMMITTED);
                  }
                  catch (SQLException exTargetConnection)
                  {
                     if (exTargetConnection.getMessage().contentEquals("Io exception: Got minus one from a read call"))
                     {
                        // Deuxième essai si l'erreur est : Io exception: Got minus one from a read call
                        writeLogMessage(Level.INFO,"Unable to connect to " + sqlResultsetTargetList.getString("NOM_CIBLE") + " (" + exTargetConnection.getMessage().replaceAll("\n"," : NL : ") + "). Will try again...");
                        targetConnection = DriverManager.getConnection("jdbc:mysql:" + sqlResultsetTargetList.getString("CONNEXION") + "/INFORMATION_SCHEMA",sqlResultsetTargetList.getString("NOM_USAGER"),sqlResultsetTargetList.getString("MOT_PASSE"));
                        targetConnection.setTransactionIsolation(Connection.TRANSACTION_READ_UNCOMMITTED);
                     }
                     else
                     {
                        throw exTargetConnection;
                     }

                  }

                  sqlDatabaseStatus = sqlMYSQLServerStatus;
               }

               else
               {
                  writeLogMessage(Level.WARNING,"Database type : " + sqlResultsetTargetList.getString("SOUS_TYPE_CIBLE") + " for target database " + sqlResultsetTargetList.getString("NOM_CIBLE") + " is not supported.");
               }

               writeLogMessage(Level.FINE,"Connected to " + sqlResultsetTargetList.getString("NOM_CIBLE") + ".");
            }
            catch (SQLException exTargetConnection)
            {
               // Échec de connexion à la base de données cible
               monitorError = true;
               writeLogMessage(Level.INFO,"Unable to connect to " + sqlResultsetTargetList.getString("NOM_CIBLE") + " (" + exTargetConnection.getMessage().replaceAll("\n"," : NL : ") + ").");

               try
               {
                  // Enregistrement du statut de la cible - Préparation des paramètres
                  sqlStmtTargetStatusDN.setString("A_TYPE_CIBLE","BD");
                  sqlStmtTargetStatusDN.setString("A_NOM_CIBLE",sqlResultsetTargetList.getString("NOM_CIBLE"));
                  sqlStmtTargetStatusDN.setString("A_STATUT","DN");

                  // Exécution
                  sqlStmtTargetStatusDN.execute();
               }
               catch (SQLException ex)
               {
                  writeLogMessage(Level.SEVERE,"Unable to send the target status to SDBM repository for target " + sqlResultsetTargetList.getString("NOM_CIBLE") + " (" + ex.getMessage().replaceAll("\n"," : NL : ") + ").");
               }
            }

            //
            // Recherche de l'information sur la cible
            //
            if (!monitorError)
            {
               try
               {
                  // Correctif pour MySQL 5.0.x (GLOBAL_STATUS et GLOBAL_VARIABLES ne sont pas dans INFORMATION_SCHEMA)
                  if (sqlResultsetTargetList.getString("SOUS_TYPE_CIBLE").contentEquals("MY"))
                  {
                     // Recherche du UPTIME
                     writeLogMessage(Level.FINE,"SQL : " + sqlMYSQLServerStatusUptime + " will be execute on target " + sqlResultsetTargetList.getString("NOM_CIBLE") + ".");
                     prepSqlStmt = targetConnection.prepareStatement(sqlMYSQLServerStatusUptime);
                     sqlResultsetDatabaseStatus = prepSqlStmt.executeQuery();
                     sqlResultsetDatabaseStatus.next();

                     String MySQLUptime = sqlResultsetDatabaseStatus.getString(2);
                     writeLogMessage(Level.FINE,"__UPTIME__ = " + MySQLUptime);

                     sqlDatabaseStatus = sqlDatabaseStatus.replaceAll("__UPTIME__",MySQLUptime);

                     // Recherche du LOG_ERROR
                     writeLogMessage(Level.FINE,"SQL : " + sqlMYSQLServerStatusLogError + " will be execute on target " + sqlResultsetTargetList.getString("NOM_CIBLE") + ".");
                     prepSqlStmt = targetConnection.prepareStatement(sqlMYSQLServerStatusLogError);
                     sqlResultsetDatabaseStatus = prepSqlStmt.executeQuery();
                     sqlResultsetDatabaseStatus.next();

                     String MySQLLogError = sqlResultsetDatabaseStatus.getString(2);
                     writeLogMessage(Level.FINE,"__LOG_ERROR__ = " + MySQLLogError);

                     if (MySQLLogError.contentEquals(""))
                     {
                        sqlDatabaseStatus = sqlDatabaseStatus.replaceAll("__LOG_ERROR__","NULL");
                     }
                     else
                     {
                        sqlDatabaseStatus = sqlDatabaseStatus.replaceAll("__LOG_ERROR__",MySQLLogError);
                     }

                  }

                  writeLogMessage(Level.FINE,"SQL : " + sqlDatabaseStatus + " will be execute on target " + sqlResultsetTargetList.getString("NOM_CIBLE") + ".");
                  prepSqlStmt = targetConnection.prepareStatement(sqlDatabaseStatus);
                  sqlResultsetDatabaseStatus = prepSqlStmt.executeQuery();
                  sqlResultsetDatabaseStatus.next();

                  // Statistique
                  statSaveTargetConnection(sqlResultsetTargetList.getString("NOM_CIBLE"), (System.currentTimeMillis() - statStart));

                  // Correctif Microsoft SQL Server 2005 - si nous obtenons un STARTUP_TIME = 1900-01-01 00:00:00 - considerons la cible comme non-disponible (en cours d'initialisation)
                  if (sqlResultsetTargetList.getString("SOUS_TYPE_CIBLE").contentEquals("MS") && sqlResultsetDatabaseStatus.getString("A_STARTUP_TIME").contentEquals("1900-01-01 00:00:00"))
                  {
                     // Base de données SQL en cours d'initialisation
                     monitorError = true;
                     writeLogMessage(Level.INFO,"The startup date of target " + sqlResultsetTargetList.getString("NOM_CIBLE") + " is not valid (that could be cause by SQL startup in progress).  Target status will be DOWN.");

                     try
                     {
                        // Enregistrement du statut de la cible - Préparation des paramètres
                        sqlStmtTargetStatusDN.setString("A_TYPE_CIBLE","BD");
                        sqlStmtTargetStatusDN.setString("A_NOM_CIBLE",sqlResultsetTargetList.getString("NOM_CIBLE"));
                        sqlStmtTargetStatusDN.setString("A_STATUT","DN");

                        // Exécution
                        sqlStmtTargetStatusDN.execute();
                     }
                     catch (SQLException ex)
                     {
                        writeLogMessage(Level.SEVERE,"Unable to send the target status to SDBM repository for target " + sqlResultsetTargetList.getString("NOM_CIBLE") + " (" + ex.getMessage().replaceAll("\n"," : NL : ") + ").");
                     }
                  }

                  // Correctif Oracle par version
                  try
                  {
                     // Retrait "ORA : " ex extraction de la version en numérique
                     oraVersion = Integer.parseInt(sqlResultsetDatabaseStatus.getString("A_VERSION").substring(6,sqlResultsetDatabaseStatus.getString("A_VERSION").indexOf('.')));
                  }
                  catch (Exception ex)
                  {
                     writeLogMessage(Level.SEVERE,"Unable to get the Oracle version (" + sqlResultsetDatabaseStatus.getString("A_VERSION").substring(6,sqlResultsetDatabaseStatus.getString("A_VERSION").indexOf('.')) + ") for target " + sqlResultsetTargetList.getString("NOM_CIBLE") + ".");
                     oraVersion = -1;
                  }

                  // 12c - localisation du fichier alert.log
                  if (sqlResultsetTargetList.getString("SOUS_TYPE_CIBLE").contentEquals("OR") && oraVersion > 11)
                  {
                     writeLogMessage(Level.FINE,"SQL : " + sqlOracleBDP12C + " will be execute on target " + sqlResultsetTargetList.getString("NOM_CIBLE") + ".");
                     prepSqlStmt = targetConnection.prepareStatement(sqlOracleBDP12C);
                     sqlResultsetDatabaseStatusAlt = prepSqlStmt.executeQuery();
                     sqlResultsetDatabaseStatusAlt.next();
                  }

                  // 18c - version complète
                  if (sqlResultsetTargetList.getString("SOUS_TYPE_CIBLE").contentEquals("OR") && oraVersion > 12)
                  {
                     writeLogMessage(Level.FINE,"SQL : " + sqlOracleVersion18c + " will be execute on target " + sqlResultsetTargetList.getString("NOM_CIBLE") + ".");
                     prepSqlStmt = targetConnection.prepareStatement(sqlOracleVersion18c);
                     sqlResultsetDatabaseVersionAlt = prepSqlStmt.executeQuery();
                     sqlResultsetDatabaseVersionAlt.next();
                  }

               }
               catch (SQLException ex)
               {
                  monitorError = true;
                  writeLogMessage(Level.SEVERE,"Unable to get the information status from target " + sqlResultsetTargetList.getString("NOM_CIBLE") + " (" + ex.getMessage().replaceAll("\n"," : NL : ") + ").");
               }
            }

            //
            // Enregistrement du statut de la cible
            //
            if (!monitorError)
            {
               try
               {
                  // Enregistrement du statut de la cible - Préparation des paramètres
                  sqlStmtTargetStatusUP.setString("A_TYPE_CIBLE","BD");
                  sqlStmtTargetStatusUP.setString("A_NOM_CIBLE",sqlResultsetTargetList.getString("NOM_CIBLE"));
                  sqlStmtTargetStatusUP.setString("A_STATUT","UP");
                  sqlStmtTargetStatusUP.setTimestamp("A_STARTUP_TIME",Timestamp.valueOf(sqlResultsetDatabaseStatus.getString("A_STARTUP_TIME")));
                  sqlStmtTargetStatusUP.setString("A_NOM_SERVEUR",sqlResultsetDatabaseStatus.getString("A_NOM_SERVEUR"));
                  sqlStmtTargetStatusUP.setString("A_NOM_INSTANCE",sqlResultsetDatabaseStatus.getString("A_NOM_INSTANCE"));

                  // Oracle : Obtenir la valeur à partir de V$DIAG_INFO si 12c et plus
                  if (sqlResultsetTargetList.getString("SOUS_TYPE_CIBLE").contentEquals("OR") && oraVersion > 11)
                  {
                     sqlStmtTargetStatusUP.setString("A_FICHIER_ALERTE",sqlResultsetDatabaseStatusAlt.getString("A_FICHIER_ALERTE"));
                  }
                  else
                  {
                     sqlStmtTargetStatusUP.setString("A_FICHIER_ALERTE",sqlResultsetDatabaseStatus.getString("A_FICHIER_ALERTE"));
                  }

                  // Oracle : Obtenir la valeur à partir de VERSION_FULL si 18c et plus
                  if (sqlResultsetTargetList.getString("SOUS_TYPE_CIBLE").contentEquals("OR") && oraVersion > 12)
                  {
                     sqlStmtTargetStatusUP.setString("A_VERSION",sqlResultsetDatabaseVersionAlt.getString("A_VERSION"));
                  }
                  else
                  {
                     sqlStmtTargetStatusUP.setString("A_VERSION",sqlResultsetDatabaseStatus.getString("A_VERSION"));
                  }

                  // Exécution
                  sqlStmtTargetStatusUP.execute();

                  // Libération des ressources - base de données cible
                  sqlResultsetDatabaseStatus.close();
                  sqlResultsetDatabaseStatus = null;

                  prepSqlStmt.close();
                  prepSqlStmt = null;
               }
               catch (SQLException ex)
               {
                  monitorError = true;
                  writeLogMessage(Level.SEVERE,"Unable to send the target status to SDBM repository for target " + sqlResultsetTargetList.getString("NOM_CIBLE") + " (" + ex.getMessage().replaceAll("\n"," : NL : ") + ").");
               }
            }

            //
            // Traitement de événements / réparations de la cible
            //
            if (!monitorError)
            {
               monitorEvents(sqlResultsetTargetList.getString("NOM_CIBLE"),sqlResultsetTargetList.getString("SOUS_TYPE_CIBLE"));
               try
               {
                  // Enregistrement du statut de l'événement - Préparation des paramètres
                  sqlStmtEventReturnHandling.setString("A_NOM_CIBLE",sqlResultsetTargetList.getString("NOM_CIBLE"));

                  // Exécution
                  sqlStmtEventReturnHandling.execute();
               }
               catch (SQLException ex)
               {
                  writeLogMessage(Level.SEVERE,"Error while processing the status change within SDBM repository for target " + sqlResultsetTargetList.getString("NOM_CIBLE") + " (" + ex.getMessage().replaceAll("\n"," : NL : ") + ").");
               }

               monitorRepairs(sqlResultsetTargetList.getString("NOM_CIBLE"));
            }

            //
            // Libération des ressources cibles
            //
            try
            {
               // En cas d'erreur
               if (sqlResultsetDatabaseStatus != null)
                  sqlResultsetDatabaseStatus.close();
               sqlResultsetDatabaseStatus = null;

               // En cas d'erreur
               if (prepSqlStmt != null)
                  prepSqlStmt.close();
               prepSqlStmt = null;

               // Fermeture de la connexion cible
               if (targetConnection != null && !targetConnection.isClosed())
               {
                  targetConnection.close();
                  writeLogMessage(Level.FINE,"Disconnected from " + sqlResultsetTargetList.getString("NOM_CIBLE") + ".");
               }

               targetConnection = null;
            }
            catch (SQLException ex)
            {
               writeLogMessage(Level.WARNING,"Error while releasing resources from target database " + sqlResultsetTargetList.getString("NOM_CIBLE") + " - monitor (" + ex.getMessage().replaceAll("\n"," : NL : ") + ").");
            }

            // Fin de la transaction
            try
            {
               repositoryConnection.commit();
            }
            catch (SQLException ex)
            {
               writeLogMessage(Level.SEVERE,"Error on commit within SDBM repository for target " + sqlResultsetTargetList.getString("NOM_CIBLE") + " (" + ex.getMessage().replaceAll("\n"," : NL : ") + ").");
            }

         }
         // Fin de l'instruction while
         setIdentifier("--");
         writeHangCheckInfo(0,"--");


         //
         // Libération des ressources (niveau référentiel)
         //
         try
         {
            // Générale
            infoOracle.clear();
            infoOracle = null;

            sqlResultsetTargetList.close();
            sqlResultsetTargetList = null;

            sqlStmtEventReturnHandling.close();
            sqlStmtEventReturnHandling = null;

            sqlStmtTargetStatusUP.close();
            sqlStmtTargetStatusUP = null;

            sqlStmtTargetStatusDN.close();
            sqlStmtTargetStatusDN = null;

            sqlStmtTargetList.close();
            sqlStmtTargetList = null;
         }
         catch (SQLException ex)
         {
            writeLogMessage(Level.WARNING,"Error while releasing repository resources for monitor.");
         }
      }
      catch (SQLException ex)
      {
         writeLogMessage(Level.SEVERE,"Unable to get the target list (" + ex.getMessage().replaceAll("\n"," : NL : ") + ").");
      }
   }


   //************************************************************************
   //*                                                                      *
   //* Méthode :                                                            *
   //*    start                                                             *
   //*                                                                      *
   //* Description :                                                        *
   //*    Execution du programme principal.                                 *
   //*                                                                      *
   //************************************************************************
   public void start()
   {
      // Préparation du système de journalisation
      try
      {
         logFile = new FileHandler("log/" + pgmname + ".%g.log",10485760,5);
      }
      catch (IOException e)
      {
         writeLogMessage(Level.SEVERE, "Unable to open logfile (./log/" + pgmname + ".n.log)");
         System.exit(1);
      }
      logFormatter = new SDBMLogFormatter();
      logFile.setFormatter(logFormatter);
      logFile.setLevel(Level.FINEST);  // Temporaire (jusqu'à la connexion au référentiel)

      try
      {
         writeLogMessage(Level.INFO,pgmname + " version " + version + " (schema " + pSDBMSchema + ")");

         //
         // Chargement du fichier de paramètre
         //
         writeLogMessage(Level.INFO,"Reading properties files...");
         Properties prop = loadParams(pgmname);
         writeLogMessage(Level.INFO,"Reading properties files completed.");

         //
         // Sauvegarde des paramètres
         //
         pSDBMConnection = prop.getProperty("SDBMConnection");
         if (pSDBMConnection == null)
         {
            pSDBMConnection = "";
         }

         pSDBMUserName = prop.getProperty("SDBMUserName");
         if (pSDBMUserName == null)
         {
            pSDBMUserName = "";
            pSDBMPassword = "";
         }
         else
         {
            // Si le nom d'usager n'est pas vide
            pSDBMPassword = prop.getProperty("SDBMPassword");
            if (pSDBMPassword == null)
            {
               pSDBMPassword = "";
            }
         }

         //
         // Affichage des paramètres
         //
         writeLogMessage(Level.INFO,"The following initialisation parameters will be used :");

         // SDBMConnection
         writeLogMessage(Level.INFO,"SDBMConnection : " + pSDBMConnection);

         // SDBMUserName et pSDBMPassword
         writeLogMessage(Level.INFO,"SDBMUserName   : " + pSDBMUserName);
         writeLogMessage(Level.INFO,"SDBMPassword   : * String of " + pSDBMPassword.length() + " car. *");

         //
         // Validation des paramètres
         //
         writeLogMessage(Level.INFO,"Checking initialisation parameters...");

         if (pSDBMConnection.contentEquals(""))
         {
            writeLogMessage(Level.SEVERE,"SDBMConnection is a mandatory parameters.");
            System.exit(1);
         }
         if (pSDBMUserName.contentEquals(""))
         {
            writeLogMessage(Level.SEVERE,"SDBMUserName is a mandatory parameters.");
            System.exit(1);
         }
         if (pSDBMPassword.contentEquals(""))
         {
            writeLogMessage(Level.SEVERE,"SDBMPassword is a mandatory parameters.");
            System.exit(1);
         }

         writeLogMessage(Level.INFO,"Checking initialisation parameters completed.");


         // Traitement principal
         writeLogMessage(Level.INFO,"Registering JDBC drivers...");
         DriverManager.registerDriver(new oracle.jdbc.driver.OracleDriver());
         writeLogMessage(Level.INFO,"oracle.jdbc.driver.OracleDriver() has been registered.");
         DriverManager.registerDriver(new com.microsoft.sqlserver.jdbc.SQLServerDriver());
         writeLogMessage(Level.INFO,"com.microsoft.sqlserver.jdbc.SQLServerDriver() has been registered.");
         DriverManager.registerDriver(new com.mysql.cj.jdbc.Driver());
         writeLogMessage(Level.INFO,"com.mysql.cj.jdbc.Driver() has been registered.");
         writeLogMessage(Level.INFO,"Registering JDBC drivers completed.");

         int  intGarbageCollection = 0;
         long statStart;
         while (true)
         {
            // Mise à jour du compteur avant GC
            if (intGarbageCollection != 0)
            {
               intGarbageCollection--;
            }
            else
            {
               writeLogMessage(Level.FINE,"Garbage collection is force to run every " + passBeforeGarbageCollection + " completed pass.  Invoking System.gc()...");
               writeLogMessage(Level.FINE,"Java memory in use - before garbage collection : " + (Runtime.getRuntime().totalMemory() - Runtime.getRuntime().freeMemory()) + " bytes.");
               System.gc();
               writeLogMessage(Level.FINE,"Java memory in use - after garbage collection  : " + (Runtime.getRuntime().totalMemory() - Runtime.getRuntime().freeMemory()) + " bytes.");
               intGarbageCollection = passBeforeGarbageCollection;
            }

            statDisplay();
            statStart = System.currentTimeMillis();
            monitor();
            statSaveCompletedPass((System.currentTimeMillis() - statStart));
            Thread.sleep(pSDBMSleepTime * 1000);
         }

      }

      catch(MissingResourceException ex)
      {
         // Erreur du lecture du fichier de configuration
         writeLogMessage(Level.SEVERE,"Unable to read " + pgmname + ".properties file.");
         System.exit(1);
      }
      catch(Exception ex)
      {
         // Erreur générale
         writeLogMessage(Level.SEVERE,ex.getMessage().replaceAll("\n"," : NL : "));
      }

   }


   //************************************************************************
   //*                                                                      *
   //* Méthode :                                                            *
   //*    shutdown                                                          *
   //*                                                                      *
   //* Description :                                                        *
   //*    Arrêt du programme principal.                                     *
   //*                                                                      *
   //************************************************************************
   public void shutdown()
   {
      writeLogMessage(Level.INFO, "Shutdown initiated...");

      // Fermeture de la connexion à une cible (s'il y a lieu)
      if (targetConnection != null)
      {
         try
         {
            writeLogMessage(Level.INFO,"Closing target connection...");
            targetConnection.close();
            writeLogMessage(Level.INFO,"Closing target connection completed.");
         }
         catch (SQLException ex)
         {
            writeLogMessage(Level.WARNING,"Error while closing target connection (" + ex.getMessage().replaceAll("\n"," : NL : ") + ").");
            targetConnection = null;
         }
      }

      // Fermeture de la connexion au référentiel (s'il y a lieu)
      if (repositoryConnection != null)
      {
         try
         {
            writeLogMessage(Level.INFO,"Closing repository connection...");
            repositoryConnection.rollback();
            repositoryConnection.close();
            repositoryConnection = null;
            writeLogMessage(Level.INFO,"Closing repository connection completed.");
         }
         catch (SQLException ex)
         {
            writeLogMessage(Level.WARNING,"Error while closing repository connection (" + ex.getMessage().replaceAll("\n"," : NL : ") + ").");
            repositoryConnection = null;
         }
      }
      writeLogMessage(Level.INFO, "Shutdown completed.");

      if (logFile != null)
         logFile.close();
   }


   //************************************************************************
   //*                                                                      *
   //* Méthode :                                                            *
   //*    main                                                              *
   //*                                                                      *
   //* Description :                                                        *
   //*    Démarrage du programme principal.                                 *
   //*                                                                      *
   //************************************************************************

   /**
    * @param args
    */
   public static void main(String args[])
   {
      // Ajustement de la langue
      Locale.setDefault(Locale.ENGLISH);

      // Réception du paramètre s'il y a lieu
      try
      {
         pSDBMSchema = args[0];
      }
      catch (ArrayIndexOutOfBoundsException ex)
      {
         pSDBMSchema = schname;
      }

      IApp app = new SDBMSrv();
      ShutdownInterceptor shutdownInterceptor = new ShutdownInterceptor(app);
      Runtime.getRuntime().addShutdownHook(shutdownInterceptor);
      app.start();
   }

}
