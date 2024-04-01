//***************************************************************************
//*                                                                         *
//* Copyright (c) 2008-2024 Benoit Bouthillier. All rights reserved.        *
//* Licensed under the MIT license.                                         *
//* See LICENSE file in the project root for full license information.      *
//*                                                                         *
//***************************************************************************
//*                                                                         *
//* Fichier :                                                               *
//*    SDBMAgt.java                                                         *
//*                                                                         *
//* Description :                                                           *
//*    Agent SDBM                                                           *
//*                                                                         *
//***************************************************************************


import java.io.BufferedReader;
import java.io.ByteArrayInputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;

import java.io.InputStreamReader;
import java.io.RandomAccessFile;

import java.io.StringReader;

import java.net.InetAddress;

import java.sql.CallableStatement;
import java.sql.Connection;
import java.sql.DriverManager;

import java.sql.ResultSet;
import java.sql.SQLException;

import java.sql.Timestamp;

import java.text.SimpleDateFormat;

import java.util.ArrayList;
import java.util.Calendar;
import java.util.Date;
import java.util.Enumeration;
import java.util.GregorianCalendar;
import java.util.Hashtable;
import java.util.Iterator;
import java.util.LinkedList;
import java.util.List;
import java.util.ListIterator;
import java.util.Locale;
import java.util.MissingResourceException;
import java.util.NoSuchElementException;
import java.util.Properties;
import java.util.ResourceBundle;
import java.util.logging.FileHandler;
import java.util.logging.Level;
import java.util.logging.LogRecord;
import java.util.logging.SimpleFormatter;

import java.util.regex.Pattern;

import oracle.jdbc.OracleTypes;

import org.hyperic.sigar.Sigar;
import org.hyperic.sigar.SigarException;
import org.hyperic.sigar.SysInfo;
import org.hyperic.sigar.Uptime;
import org.hyperic.sigar.CpuInfo;
import org.hyperic.sigar.CpuPerc;
import org.hyperic.sigar.Mem;
import org.hyperic.sigar.SigarLoader;
import org.hyperic.sigar.Swap;


public class SDBMAgt implements IApp
{

   //************************************************************************
   //* Variables globales                                                   *
   //************************************************************************

   // Identification
   private static final  String           pgmname = "SDBMAgt";
   private static final  String           schname = "SDBM";
   private static final  String           version = "0.19";

   // Journalisation
   private static final  SimpleDateFormat dateFormat = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss");
   private static        FileHandler      logFile;
   private static        SDBMLogFormatter logFormatter;

   // Paramètres d'exécution
   private static        String           pSDBMSchema;
   private               String           pSDBMConnection;
   private               String           pSDBMUserName;
   private               String           pSDBMPassword;
   private               String           pSDBMLogLevel;
   private               String           pSDBMHostName;
   private               String           pSDBMTaskScheduler;
   private               String           pSDBMTaskSchedulerAllowBackQuotes;
   private               String           pSDBMSysStatistics;
   private               String           pSDBMCPUStatistics;
   private               int              pSDBMSleepTime    = 999;
   private               int              pSDBMSleepTimeJob = 999;

   // Variables d'exécution
   private static final  int              passBeforeGarbageCollection = 120;
   private static final  int              sleepInternal               = 5;
   private static final  int              sleepTimeOnConnectionError  = 15;
   private static final  Pattern          oraDatePattern              = Pattern.compile("[A-Z][a-z]*[ ][A-Z][a-z]*[ ]*[0-9]*[ ][0-9]*:[0-9]*:[0-9]*[ ][0-9]*");

   private               Calendar         calendar = new GregorianCalendar();

   private               int              dayOfLastDailyMaintenance   = -1;
   private               int              minOfLastSysStatistics      = -1;
   private               double           dblSWPLastPageIn            = -1;
   private               double           dblSWPLastPageOut           = -1;

   private               Connection       repositoryConnection;
   private               Properties       repositoryProperties;


   // Acces SIGAR
   private static Sigar sigar = new Sigar();

   private class EnregAlert
   {
      String  targetName;
      String  targetSubType;
      String  fileName;
      long    filePosition;
      boolean isStillActive;
   }
   private               Hashtable<String, EnregAlert> htAlert = new Hashtable<String, EnregAlert>();

   private class EnregJob
   {
      long    submissionID;
      String  jobName;
      String  executableName;
      String  parameters;
      String  directoryName;
      String  logFileName;
      long    logFilePosition;
      Process process;
   }
   private               Hashtable<String, EnregJob> htJob   = new Hashtable<String, EnregJob>();

   private               Properties                  propAC  = new Properties();


   //************************************************************************
   //*                                                                      *
   //* Classe :                                                             *
   //*    SDBMLogFormatter                                                  *
   //*                                                                      *
   //************************************************************************
   private class SDBMLogFormatter extends SimpleFormatter
   {

      public SDBMLogFormatter()
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
   //*    Envoi du message dans le journal de l'application.                *
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

      // Envoi du message à la base de données (best effort) - sauf DEBUG (FINE)
      if (repositoryConnection != null && logFile != null && level.intValue() >= logFile.getLevel().intValue() && level != Level.FINE)
      {
         CallableStatement sqlStmt;

         try
         {
            sqlStmt = repositoryConnection.prepareCall("{call " + pSDBMSchema + ".SDBM_AGENT.JOURNALISER(?,?,?)}");

            // Préparation des paramètres
            sqlStmt.setString("A_SOURCE",pgmname + " (" + pSDBMHostName + ")");
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
   //*    wait                                                              *
   //*                                                                      *
   //* Description :                                                        *
   //*    Permet au thread courrant d'attende un nombre spécifié de         *
   //*    secondes.                                                         *
   //*                                                                      *
   //************************************************************************
   private void wait(int seconds)
   {
      if (seconds > 0)
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
   }


   //************************************************************************
   //*                                                                      *
   //* Méthode :                                                            *
   //*    setSleepTimeJob                                                   *
   //*                                                                      *
   //* Description :                                                        *
   //*    Ajustement de la fréquence d'exécution (tâche).                   *
   //*                                                                      *
   //************************************************************************
   private void setSleepTimeJob(int sleepTime)
   {
      if (sleepTime < sleepInternal || sleepTime > 999)
      {
         pSDBMSleepTimeJob = 30;
         writeLogMessage(Level.WARNING,"Invalid value for parameter sleepTime - Job (setSleepTime). 30 seconds will be used.");
      }
      else
      {
         if (sleepTime != pSDBMSleepTimeJob)
         {
            pSDBMSleepTimeJob = sleepTime;
            writeLogMessage(Level.CONFIG,"The new value for parameter sleepTime - Job is " + pSDBMSleepTimeJob + " seconds.");
         }
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
      if (sleepTime < sleepInternal || sleepTime > 999)
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
   //*    loadAuthorizedCommands                                            *
   //*                                                                      *
   //* Description :                                                        *
   //*    Chargment du fichier de paramètre (AuthorizedCommands).           *
   //*                                                                      *
   //************************************************************************
   private void loadAuthorizedCommands()
   {
      FileInputStream         fpProp;
      String                  propertyFileContents;

      Properties              prop = new Properties();
      Enumeration<Object> em;

      int                     nbProp = 0;
      String                  key;
      String                  dirValue;
      String                  cmdValue;


      try
      {
         // Lecture du fichier dans une chaine (permettre le replace de // par ////)
         byte[] buffer = new byte[(int) new File(pgmname + ".AuthorizedCommands.properties").length()];
         fpProp = new FileInputStream(pgmname + ".AuthorizedCommands.properties");
         fpProp.read(buffer);
         fpProp.close();
         propertyFileContents = new String(buffer);

         prop.load(new ByteArrayInputStream(propertyFileContents.replace("\\","\\\\").getBytes()));
         em = prop.keys();

         while (em.hasMoreElements())
         {
            key      = (String)em.nextElement();
            dirValue = null;
            cmdValue = null;

            if (key.startsWith("dir"))
            {
               String[] keySplit = key.split("\\.",2);
               dirValue = prop.getProperty("dir." + keySplit[1]);
               cmdValue = prop.getProperty("cmd." + keySplit[1]);

               if (cmdValue != null)
               {
                  nbProp++;
                  propAC.put("dir." + nbProp, dirValue);
                  propAC.put("cmd." + nbProp, cmdValue);
               }
            }
         }
      }
      catch(IOException ex)
      {
         writeLogMessage(Level.CONFIG,"The file " + pgmname + ".AuthorizedCommands.properties does not exists.");
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

            // Create the properties object that holds all database details
            if (repositoryProperties == null)
            {
               repositoryProperties = new Properties();
               repositoryProperties.put("user",pSDBMUserName);
               repositoryProperties.put("password",pSDBMPassword);
               repositoryProperties.put("SetBigStringTryClob","true");
            }

            repositoryConnection = DriverManager.getConnection("jdbc:oracle:thin:@" + pSDBMConnection,repositoryProperties);
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
   //*    collectSystemStatistics                                           *
   //*                                                                      *
   //* Description :                                                        *
   //*    Collecte des statistiques du système.                             *
   //*                                                                      *
   //************************************************************************
   private void collectSystemStatistics()
   {
      //
      // Probing system information
      //
      CpuPerc[] cpusinfo    = null;
      CpuPerc   cpuinfos    = null;
      Mem       meminfo     = null;
      Swap      swapinfo    = null;
      double[]  loadAvgInfo = null;


      if (pSDBMCPUStatistics.equalsIgnoreCase("AC"))
      {
         try
         {
            // CpusInfo
            cpusinfo = sigar.getCpuPercList();
         }
         catch (SigarException ex)
         {
            writeLogMessage(Level.WARNING,"SIGAR error : call failed to getCpuPercList() (" + ex.getMessage().replaceAll("\n"," : NL : ") + ").");
         }
      }
      else
      {
         try
         {
            // Cpu
            cpuinfos = sigar.getCpuPerc();
         }
         catch (SigarException ex)
         {
            writeLogMessage(Level.WARNING,"SIGAR error : call failed to getCpuPerc() (" + ex.getMessage().replaceAll("\n"," : NL : ") + ").");
         }
      }

      try
      {
         // Mem
         meminfo = sigar.getMem();
      }
      catch (SigarException ex)
      {
         writeLogMessage(Level.WARNING,"SIGAR error : call failed to getMem() (" + ex.getMessage().replaceAll("\n"," : NL : ") + ").");
      }

      try
      {
         // Swap
         swapinfo = sigar.getSwap();
      }
      catch (SigarException ex)
      {
         writeLogMessage(Level.WARNING,"SIGAR error : call failed to getSwap() (" + ex.getMessage().replaceAll("\n"," : NL : ") + ").");
      }

      if (!SigarLoader.IS_WIN32)
      {
         try
         {
            // LoadAverage
            loadAvgInfo = sigar.getLoadAverage();
         }
         catch (SigarException ex)
         {
            writeLogMessage(Level.WARNING,"SIGAR error : call failed to getLoadAverage() (" + ex.getMessage().replaceAll("\n"," : NL : ") + ").");
         }
      }


      CallableStatement sqlStmtSaveDynStats = null;

      try
      {
         // Préparation des appels (obtenir la liste / enregistrement des statuts)
         sqlStmtSaveDynStats = repositoryConnection.prepareCall("{call " + pSDBMSchema + ".SDBM_AGENT.ENREGISTRER_INFO_DYNAMIQUE(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)}");

         // Enregistrement des paramètres
         sqlStmtSaveDynStats.setString("A_NOM_SERVEUR",pSDBMHostName);
         sqlStmtSaveDynStats.setTimestamp("A_DH_COLLECTE_DONNEE",new Timestamp(calendar.getTimeInMillis()));

         if (meminfo != null)
         {
            sqlStmtSaveDynStats.setLong("A_MEM_TOTAL",meminfo.getTotal());
            sqlStmtSaveDynStats.setDouble("A_MEM_ACTUAL_USED",meminfo.getActualUsed());
            sqlStmtSaveDynStats.setDouble("A_MEM_ACTUAL_FREE",meminfo.getActualFree());
            sqlStmtSaveDynStats.setDouble("A_MEM_USED",meminfo.getUsed());
            sqlStmtSaveDynStats.setDouble("A_MEM_FREE",meminfo.getFree());
         }
         else
         {
            sqlStmtSaveDynStats.setLong("A_MEM_TOTAL",-1);
            sqlStmtSaveDynStats.setDouble("A_MEM_ACTUAL_USED",-1);
            sqlStmtSaveDynStats.setDouble("A_MEM_ACTUAL_FREE",-1);
            sqlStmtSaveDynStats.setDouble("A_MEM_USED",-1);
            sqlStmtSaveDynStats.setDouble("A_MEM_FREE",-1);
         }

         if (swapinfo != null)
         {
            sqlStmtSaveDynStats.setDouble("A_SWP_TOTAL",swapinfo.getTotal());
            sqlStmtSaveDynStats.setDouble("A_SWP_USED",swapinfo.getUsed());
            sqlStmtSaveDynStats.setDouble("A_SWP_FREE",swapinfo.getFree());
            sqlStmtSaveDynStats.setDouble("A_SWP_PAGE_IN",swapinfo.getPageIn());
            sqlStmtSaveDynStats.setDouble("A_SWP_PAGE_OUT",swapinfo.getPageOut());

            if (dblSWPLastPageIn == -1)
            {
               // Première passe - initialisation
               sqlStmtSaveDynStats.setDouble("A_SWP_DELTA_PAGE_IN",-1);
               sqlStmtSaveDynStats.setDouble("A_SWP_DELTA_PAGE_OUT",-1);
               dblSWPLastPageIn  = swapinfo.getPageIn();
               dblSWPLastPageOut = swapinfo.getPageOut();
            }
            else
            {
               sqlStmtSaveDynStats.setDouble("A_SWP_DELTA_PAGE_IN",(swapinfo.getPageIn() - dblSWPLastPageIn));
               sqlStmtSaveDynStats.setDouble("A_SWP_DELTA_PAGE_OUT",(swapinfo.getPageOut() - dblSWPLastPageOut));
               dblSWPLastPageIn  = swapinfo.getPageIn();
               dblSWPLastPageOut = swapinfo.getPageOut();
            }
         }
         else
         {
            sqlStmtSaveDynStats.setDouble("A_SWP_TOTAL",-1);
            sqlStmtSaveDynStats.setDouble("A_SWP_USED",-1);
            sqlStmtSaveDynStats.setDouble("A_SWP_FREE",-1);
            sqlStmtSaveDynStats.setDouble("A_SWP_PAGE_IN",-1);
            sqlStmtSaveDynStats.setDouble("A_SWP_PAGE_OUT",-1);
            sqlStmtSaveDynStats.setDouble("A_SWP_DELTA_PAGE_IN",-1);
            sqlStmtSaveDynStats.setDouble("A_SWP_DELTA_PAGE_OUT",-1);
         }

         if (cpusinfo != null)
         {
            String strListUser  = "";
            String strListSys   = "";
            String strListIdle  = "";
            String strListWait  = "";
            String strListNice  = "";
            String strListTotal = "";

            // CPU (détail par CPU)
            for (int i = 0; i < cpusinfo.length; i++)
            {
               if (strListUser.length() == 0)
               {
                  strListUser  = Double.toString(cpusinfo[i].getUser());
                  strListSys   = Double.toString(cpusinfo[i].getSys());
                  strListWait  = Double.toString(cpusinfo[i].getWait());
                  strListNice  = Double.toString(cpusinfo[i].getNice());
                  strListTotal = Double.toString(cpusinfo[i].getCombined());
                  strListIdle  = Double.toString(cpusinfo[i].getIdle());
               }
               else
               {
                  strListUser  = strListUser  + "," + Double.toString(cpusinfo[i].getUser());
                  strListSys   = strListSys   + "," + Double.toString(cpusinfo[i].getSys());
                  strListWait  = strListWait  + "," + Double.toString(cpusinfo[i].getWait());
                  strListNice  = strListNice  + "," + Double.toString(cpusinfo[i].getNice());
                  strListTotal = strListTotal + "," + Double.toString(cpusinfo[i].getCombined());
                  strListIdle  = strListIdle  + "," + Double.toString(cpusinfo[i].getIdle());
               }
            }
            sqlStmtSaveDynStats.setString("A_LISTE_USER_TIME",strListUser);
            sqlStmtSaveDynStats.setString("A_LISTE_SYS_TIME",strListSys);
            sqlStmtSaveDynStats.setString("A_LISTE_WAIT_TIME",strListWait);
            sqlStmtSaveDynStats.setString("A_LISTE_NICE_TIME",strListNice);
            sqlStmtSaveDynStats.setString("A_LISTE_TOTAL_TIME",strListTotal);
            sqlStmtSaveDynStats.setString("A_LISTE_IDLE_TIME",strListIdle);

         }
         else
         {
            if (cpuinfos != null)
            {
               sqlStmtSaveDynStats.setString("A_LISTE_USER_TIME",Double.toString(cpuinfos.getUser()));
               sqlStmtSaveDynStats.setString("A_LISTE_SYS_TIME",Double.toString(cpuinfos.getSys()));
               sqlStmtSaveDynStats.setString("A_LISTE_WAIT_TIME",Double.toString(cpuinfos.getWait()));
               sqlStmtSaveDynStats.setString("A_LISTE_NICE_TIME",Double.toString(cpuinfos.getNice()));
               sqlStmtSaveDynStats.setString("A_LISTE_TOTAL_TIME",Double.toString(cpuinfos.getCombined()));
               sqlStmtSaveDynStats.setString("A_LISTE_IDLE_TIME",Double.toString(cpuinfos.getIdle()));
            }
            else
            {
               sqlStmtSaveDynStats.setString("A_LISTE_USER_TIME","");
               sqlStmtSaveDynStats.setString("A_LISTE_SYS_TIME","");
               sqlStmtSaveDynStats.setString("A_LISTE_WAIT_TIME","");
               sqlStmtSaveDynStats.setString("A_LISTE_NICE_TIME","");
               sqlStmtSaveDynStats.setString("A_LISTE_TOTAL_TIME","");
               sqlStmtSaveDynStats.setString("A_LISTE_IDLE_TIME","");
            }
         }

         if (loadAvgInfo != null)
         {
            sqlStmtSaveDynStats.setDouble("A_SYS_LOAD_AVG",loadAvgInfo[0]);
         }
         else
         {
            sqlStmtSaveDynStats.setDouble("A_SYS_LOAD_AVG",-1);
         }


         // Exécution
         sqlStmtSaveDynStats.execute();

         // Fin de la transaction
         try
         {
            repositoryConnection.commit();
         }
         catch (SQLException ex)
         {
            writeLogMessage(Level.SEVERE,"Error on commit within SDBM repository - collectSystemStatistics (" + ex.getMessage().replaceAll("\n"," : NL : ") + ").");
         }
      }
      catch (SQLException ex)
      {
         writeLogMessage(Level.SEVERE,"Unable to save the system statistics (" + ex.getMessage().replaceAll("\n"," : NL : ") + ").");
      }
      finally
      {
         //
         // Libération des ressources (niveau référentiel)
         //
         try
         {
            if (sqlStmtSaveDynStats != null)
               sqlStmtSaveDynStats.close();
            sqlStmtSaveDynStats = null;
         }
         catch (Exception ex)
         {
            writeLogMessage(Level.WARNING,"Error while releasing repository resources for collectSystemStatistics.");
         }

      }
   }


   //************************************************************************
   //*                                                                      *
   //* Méthode :                                                            *
   //*    sendLogData                                                       *
   //*                                                                      *
   //* Description :                                                        *
   //*    Envoi des données dans le référentiel SDBM.                       *
   //*                                                                      *
   //************************************************************************
   private void sendLogData(long submissionID, String journal, boolean bClear)
   {
      // Envoi vers le référentiel SDBM
      CallableStatement sqlStmtAddJobLog = null;


      if ((journal != null) && (journal.length() > 0))
      {
         writeLogMessage(Level.FINE,"Sending data to SDBM repository...");

         try
         {
            // Préparation de l'appel Oracle
            if (sqlStmtAddJobLog == null)
               sqlStmtAddJobLog = repositoryConnection.prepareCall("{call " + pSDBMSchema + ".SDBM_AGENT.AJOUTER_JOURNAL_TACHE_AGT(?,?,?)}");

            // Enregistrement du statut de l'événement - Préparation des paramètres
            sqlStmtAddJobLog.setLong("A_ID_SOUMISSION",submissionID);
            sqlStmtAddJobLog.setString("A_JOURNAL",journal);
            if (bClear)
               sqlStmtAddJobLog.setInt("A_VIDER_JOURNAL",1);
            else
               sqlStmtAddJobLog.setInt("A_VIDER_JOURNAL",0);

            // Exécution
            sqlStmtAddJobLog.execute();

            writeLogMessage(Level.FINE,"The data has been sucessfully sent to SDBM repository.");
         }
         catch (SQLException ex)
         {
            writeLogMessage(Level.SEVERE,"Unable to send the log message to SDBM repository for submission ID " + submissionID + " (" + ex.getMessage().replaceAll("\n"," : NL : ") + ").");
         }

         //
         // Libération des ressources (niveau référentiel)
         //
         try
         {
            if (sqlStmtAddJobLog != null)
               sqlStmtAddJobLog.close();
            sqlStmtAddJobLog = null;
         }
         catch (Exception ex)
         {
            writeLogMessage(Level.WARNING,"Error while releasing repository resources for sendLogData.");
         }
      }
   }


   //************************************************************************
   //*                                                                      *
   //* Méthode :                                                            *
   //*    monitorLogFile                                                    *
   //*                                                                      *
   //* Description :                                                        *
   //*    Gestion d'un fichier de journal de traitement.                    *
   //*                                                                      *
   //************************************************************************
   private void monitorLogFile(EnregJob enregJob, boolean bFinalExec)
   {
      // Statistique fichier
      File fpJobLog = null;
      long fileCurrentSize;

      // Lecture du fichier
      RandomAccessFile fileJobLog    = null;
      BufferedReader   fileJobLogBuf = null;
      StringBuilder    journal       = null;
      String           message       = null;
      boolean          skipMessage;


      //
      // Traitement régulier
      //

      if (enregJob.logFilePosition != -1 && !(enregJob.logFilePosition == 0 && bFinalExec))
      {
         // Recherche de la grosseur actuel du fichier
         fpJobLog = new File(enregJob.logFileName);
         if (fpJobLog.exists())
         {
            fileCurrentSize = fpJobLog.length();

            if (enregJob.logFilePosition != fileCurrentSize)
            {
               // Vérification de réinitialisation du fichier
               if (enregJob.logFilePosition > fileCurrentSize)
               {
                  enregJob.logFilePosition = 0;
                  writeLogMessage(Level.WARNING,"Reset of offset for file " + enregJob.logFileName + ".");
               }

               // Vérification pour traitement de fichier volumineux
               if ((enregJob.logFilePosition + 65536) < fileCurrentSize)
               {
                  writeLogMessage(Level.INFO,"The logfile " + enregJob.logFileName + " exceed size increase threashold of 64KB and will not be uploaded to SDBM repository until the end of the job.");

                  enregJob.logFilePosition = -1;
                  journal = new StringBuilder("");
                  journal.append("...\nThe logfile exceed size increase threashold of 64KB and will not be uploaded to SDBM repository until the end of the job.\n");
               }
               else
               {
                  // Le fichier à été modifié, le traitement est requis
                  writeLogMessage(Level.FINE,"Reading of file " + enregJob.logFileName + " will start at offset " + enregJob.logFilePosition + " (current size is " + fileCurrentSize + ").");

                  try
                  {
                     fileJobLog = new RandomAccessFile(fpJobLog,"r");
                     fileJobLog.seek(enregJob.logFilePosition);

                     // Initialisation du tampon journal
                     journal = new StringBuilder("");

                     skipMessage = false;
                     while (fileJobLog.getFilePointer() < fileCurrentSize)
                     {
                        if (enregJob.executableName.contentEquals("cmd.exe (/u)"))
                        {
                           // Si l'agent s'exécute sous Windows
                           message = fileJobLog.readLine().replaceAll("\0","");

                           if (!(message.length() == 0 && skipMessage))
                           {
                              // Ajout du message au tampon du journal
                              journal.append(message + "\r\n");
                           }
                           skipMessage = !skipMessage;
                        }
                        else
                        {
                           // Si l'agent ne s'exécute pas sous Windows
                           message = fileJobLog.readLine();
                           journal.append(message + "\r\n");
                        }
                     }

                     // Sauvegarde de la nouvelle fin de fichier
                     enregJob.logFilePosition = fileCurrentSize;
                     writeLogMessage(Level.FINE,"Reading of file " + enregJob.logFileName + " end at offset " + enregJob.logFilePosition + ".");

                     // Fermeture du fichier
                     fileJobLog.close();
                     fileJobLog = null;

                     // Sauvegarde du message dans le référentiel SDBM
                     sendLogData(enregJob.submissionID, journal.toString(), false);
                  }
                  catch (IOException ex)
                  {
                     writeLogMessage(Level.WARNING,"Unable to read the file " + enregJob.logFileName + " for submission ID " + enregJob.submissionID + " (" + ex.getMessage() + ").");
                  }
               }
            }
         }
         else
         {
            writeLogMessage(Level.WARNING,"Unable to get the size of the file " + enregJob.logFileName + " for submission ID " + enregJob.submissionID + " (file does not exists).");
         }
      }
      else
      {
         // Si le traitement est terminé
         if (bFinalExec)
         {
            //
            // Traitement des fichiers volumineux
            //

            // Recherche de la grosseur actuel du fichier
            fpJobLog = new File(enregJob.logFileName);
            if (fpJobLog.exists())
            {
               fileCurrentSize = fpJobLog.length();

               writeLogMessage(Level.FINE,"Reading of file " + enregJob.logFileName + " (size is " + fileCurrentSize + ").");

               try
               {
                  if (enregJob.executableName.contentEquals("cmd.exe (/u)"))
                     fileJobLogBuf = new BufferedReader(new InputStreamReader(new FileInputStream(fpJobLog),"UTF-16LE") );
                  else
                     fileJobLogBuf = new BufferedReader(new InputStreamReader(new FileInputStream(fpJobLog)) );

                  // Initialisation du tampon journal
                  journal = new StringBuilder("");

                  while ((message = fileJobLogBuf.readLine()) != null)
                  {
                     // Ajout du message au tampon du journal
                     journal.append(message + "\r\n");

                     if (journal.length() >  65536)
                     {
                        // Sauvegarde du message dans le référentiel SDBM
                        sendLogData(enregJob.submissionID, journal.toString(), bFinalExec);

                        // Vidange du tampon
                        journal = null;
                        journal = new StringBuilder("");
                        bFinalExec = false;
                     }
                  }

                  // Sauvegarde du message dans le référentiel SDBM - dernière passe
                  sendLogData(enregJob.submissionID, journal.toString(), bFinalExec);

                  writeLogMessage(Level.FINE,"Reading of file " + enregJob.logFileName + " is completed.");

                  // Fermeture du fichier
                  fileJobLogBuf.close();
                  fileJobLogBuf = null;
               }
               catch (IOException ex)
               {
                  writeLogMessage(Level.WARNING,"Unable to read the file " + enregJob.logFileName + " for submission ID " + enregJob.submissionID + " (" + ex.getMessage() + ").");
               }
            }
            else
            {
               writeLogMessage(Level.WARNING,"Unable to get the size of the file " + enregJob.logFileName + " for submission ID " + enregJob.submissionID + " (file does not exists).");
            }
         }
      }

      // Fin de la transaction
      try
      {
         repositoryConnection.commit();
      }
      catch (SQLException ex)
      {
         writeLogMessage(Level.SEVERE,"Error on commit within SDBM repository - monitorLogFile (" + ex.getMessage().replaceAll("\n"," : NL : ") + ").");
      }

   }


   //************************************************************************
   //*                                                                      *
   //* Méthode :                                                            *
   //*    setJobStatusExecRC                                                *
   //*                                                                      *
   //* Description :                                                        *
   //*    Mise à jour du statut d'exécution d'une tâche (avec code retour). *
   //*                                                                      *
   //************************************************************************
   private boolean setJobStatusExecRC(long submissionID, int returnCode)
   {
      CallableStatement sqlStmtJobStatusExec = null;
      boolean           bReturn              = false;

      // Mise à jour du statut d'exécution
      try
      {
         // Préparation de l'appel
         sqlStmtJobStatusExec = repositoryConnection.prepareCall("{call " + pSDBMSchema + ".SDBM_AGENT.CHANGER_STATUT_EXEC_TACHE_AGT(?,?,?)}");

         sqlStmtJobStatusExec.setLong("A_ID_SOUMISSION",submissionID);
         sqlStmtJobStatusExec.setString("A_STATUT_EXEC","EV");
         sqlStmtJobStatusExec.setLong("A_CODE_RETOUR",returnCode);
         sqlStmtJobStatusExec.execute();
         bReturn = true;
      }
      catch (SQLException ex1)
      {
         /* 2 tentavive pour erreur temporaire (exemple : modification du code) */
         writeLogMessage(Level.INFO,"Unable to change execution status to EV (return code : " + returnCode + ") for submission ID " + submissionID + " (" + ex1.getMessage().replaceAll("\n"," : NL : ") + "). Since this call must successfully complete, it will be retry.");

         try
         {
            // Préparation de l'appel
            sqlStmtJobStatusExec = repositoryConnection.prepareCall("{call " + pSDBMSchema + ".SDBM_AGENT.CHANGER_STATUT_EXEC_TACHE_AGT(?,?,?)}");

            sqlStmtJobStatusExec.setLong("A_ID_SOUMISSION",submissionID);
            sqlStmtJobStatusExec.setString("A_STATUT_EXEC","EV");
            sqlStmtJobStatusExec.setLong("A_CODE_RETOUR",returnCode);
            sqlStmtJobStatusExec.execute();
            bReturn = true;
         }
         catch (SQLException ex)
         {
            writeLogMessage(Level.SEVERE,"Unable to change execution status to EV (return code : " + returnCode + ") for submission ID " + submissionID + " (" + ex.getMessage().replaceAll("\n"," : NL : ") + ").");
         }
      }

      //
      // Libération des ressources (niveau référentiel)
      //
      try
      {
         if (sqlStmtJobStatusExec != null)
            sqlStmtJobStatusExec.close();
         sqlStmtJobStatusExec = null;
      }
      catch (Exception ex)
      {
         writeLogMessage(Level.WARNING,"Error while releasing repository resources for setJobStatusExec.");
      }

      return(bReturn);
   }


   //************************************************************************
   //*                                                                      *
   //* Méthode :                                                            *
   //*    setJobStatusExec                                                  *
   //*                                                                      *
   //* Description :                                                        *
   //*    Mise à jour du statut d'exécution d'une tâche.                    *
   //*                                                                      *
   //************************************************************************
   private boolean setJobStatusExec(long submissionID, String execStatus)
   {
      CallableStatement sqlStmtJobStatusExec = null;
      boolean           bReturn              = false;

      // Mise à jour du statut d'exécution
      try
      {
         // Préparation de l'appel
         sqlStmtJobStatusExec = repositoryConnection.prepareCall("{call " + pSDBMSchema + ".SDBM_AGENT.CHANGER_STATUT_EXEC_TACHE_AGT(?,?)}");

         sqlStmtJobStatusExec.setLong("A_ID_SOUMISSION",submissionID);
         sqlStmtJobStatusExec.setString("A_STATUT_EXEC",execStatus);
         sqlStmtJobStatusExec.execute();
         bReturn = true;
      }
      catch (SQLException ex1)
      {
         /* 2 tentavive pour erreur temporaire (exemple : modification du code) */
         writeLogMessage(Level.INFO,"Unable to change execution status to " + execStatus + " for submission ID " + submissionID + " (" + ex1.getMessage().replaceAll("\n"," : NL : ") + "). Since this call must successfully complete, it will be retry.");

         try
         {
            // Préparation de l'appel
            sqlStmtJobStatusExec = repositoryConnection.prepareCall("{call " + pSDBMSchema + ".SDBM_AGENT.CHANGER_STATUT_EXEC_TACHE_AGT(?,?)}");

            sqlStmtJobStatusExec.setLong("A_ID_SOUMISSION",submissionID);
            sqlStmtJobStatusExec.setString("A_STATUT_EXEC",execStatus);
            sqlStmtJobStatusExec.execute();
            bReturn = true;
         }
         catch (SQLException ex)
         {
            writeLogMessage(Level.SEVERE,"Unable to change execution status to " + execStatus + " for submission ID " + submissionID + " (" + ex.getMessage().replaceAll("\n"," : NL : ") + ").");
         }
      }

      //
      // Libération des ressources (niveau référentiel)
      //
      try
      {
         if (sqlStmtJobStatusExec != null)
            sqlStmtJobStatusExec.close();
         sqlStmtJobStatusExec = null;
      }
      catch (Exception ex)
      {
         writeLogMessage(Level.WARNING,"Error while releasing repository resources for setJobStatusExec.");
      }

      return(bReturn);
   }


   //************************************************************************
   //*                                                                      *
   //* Méthode :                                                            *
   //*    createJobProcess                                                  *
   //*                                                                      *
   //* Description :                                                        *
   //*    Création d'un processus d'exécution d'une tâche.                  *
   //*                                                                      *
   //************************************************************************
   private void createJobProcess(EnregJob enregJob)
   {
      writeLogMessage(Level.FINE,"Entering createJobProcess()");

      boolean        bUnAuthorizedCommand = false;
      boolean        bAuthorizedCommand = false;
      ProcessBuilder processBuilder;


      // Validation Back-quotes
      if (pSDBMTaskSchedulerAllowBackQuotes.equalsIgnoreCase("IN"))
      {
         // Si ce n'est pas Windows
         if ((!enregJob.executableName.contentEquals("cmd.exe (/u)")) && (!enregJob.executableName.contentEquals("cmd.exe (/a)")))
         {
            if (enregJob.parameters.contains("`"))
               bUnAuthorizedCommand = true;
         }
      }

      // Vérification que la commande n'est pas déjà rejetée sur un autre règle
      if (!bUnAuthorizedCommand)
      {
         // Vérification si la validation des arguments est activée
         if (propAC.isEmpty())
         {
            bAuthorizedCommand = true;
         }
         else
         {
            // Vérification des arguments
            Enumeration<?> em = propAC.propertyNames();
            String         key;
            String         dirValue;
            String         cmdValue;

            while (em.hasMoreElements())
            {
               key = (String)em.nextElement();

               if (key.startsWith("dir"))
               {
                  String[] keySplit = key.split("\\.",2);
                  dirValue = propAC.getProperty("dir." + keySplit[1]);
                  cmdValue = propAC.getProperty("cmd." + keySplit[1]);

                  if ((enregJob.directoryName.trim().matches(dirValue)) && (enregJob.parameters.trim().matches(cmdValue)))
                  {
                     writeLogMessage(Level.FINE,"AuthorizedCommand match has occured for " + enregJob.jobName + ", submission ID : " + enregJob.submissionID + " Directory (job): |" + enregJob.directoryName + "| = Directory (auth): |" + dirValue + "|, Command (job): |" + enregJob.parameters + "| = Command (auth): |" + cmdValue + "|");
                     bAuthorizedCommand = true;
                     break;
                  }
                  else
                  {
                     writeLogMessage(Level.FINE,"AuthorizedCommand match has not occurred for " + enregJob.jobName + ", submission ID : " + enregJob.submissionID + " Directory (job): |" + enregJob.directoryName + "| = Directory (auth): |" + dirValue + "|, Command (job): |" + enregJob.parameters + "| = Command (auth): |" + cmdValue + "|");
                  }
               }
            }
         }
      }

      // Soumission de la tâche (si la validation a passée)
      if ((!bUnAuthorizedCommand) && (bAuthorizedCommand))
      {
         if (enregJob.executableName.contentEquals("cmd.exe (/u)"))
         {
            // Windows
            processBuilder = new ProcessBuilder("cmd.exe", "/u", "/c", enregJob.parameters + " > " + enregJob.logFileName + " 2>&1");
         }
         else if (enregJob.executableName.contentEquals("cmd.exe (/a)"))
         {
            processBuilder = new ProcessBuilder("cmd.exe", "/a", "/c", enregJob.parameters + " > " + enregJob.logFileName + " 2>&1");
         }
         else
         {
            // Unix / Linux
            processBuilder = new ProcessBuilder(enregJob.executableName, "-c", enregJob.parameters + " > " + enregJob.logFileName + " 2>&1");
         }

         // Paramétrisation du processus à lancer
         processBuilder.directory(new File(enregJob.directoryName));

         try
         {
            enregJob.process = processBuilder.start();
            writeLogMessage(Level.INFO,"Job process for " + enregJob.jobName + ", submission ID : " + enregJob.submissionID + " has been sucessfully created.");

            // Mise à jour du statut d'exécution (EX : En exécution)
            setJobStatusExec(enregJob.submissionID,"EX");
         }
         catch (IOException ex)
         {
            writeLogMessage(Level.WARNING,"Unable to create the job process for " + enregJob.jobName + ", submission ID : " + enregJob.submissionID + " (" + ex.getMessage().replaceAll("\n"," : NL : ") + ").");

            // Mise à jour du statut d'exécution (SF : Problème à la soumission)
            setJobStatusExec(enregJob.submissionID,"SF");
         }
      }
      else
      {
         // Fin de la tache (UnAuthorizedCommand "utilisation des back-quotes")
         if (bUnAuthorizedCommand)
         {
            setJobStatusExec(enregJob.submissionID,"EX");
            sendLogData(enregJob.submissionID, "Not authorized to execute : The command contains back-quotes which is not allowed by SDBMTaskSchedulerAllowBackQuotes.\n\nCommand:\n" + enregJob.parameters + "\n\nIf required, see " + pgmname + ".properties for correctives mesures.\n", false);
            setJobStatusExecRC(enregJob.submissionID,128);

            // Retrait de la liste d'exécution
            writeLogMessage(Level.WARNING,enregJob.jobName + " (submission ID : " + enregJob.submissionID + ") has completed with a return code of 128 (Not authorized to execute)");
            htJob.remove(enregJob.jobName);
         }
         else
         {
            // Fin de la tache (AuthorizedCommands)
            setJobStatusExec(enregJob.submissionID,"EX");
            sendLogData(enregJob.submissionID, "Not authorized to execute : The command is not matching any authorized commands.\n\nCommand:\n" + enregJob.parameters + "\n\nAuthorized commands:\n", false);

            // Affichage de la liste (journal de la tâche)
            Enumeration<?> em = propAC.propertyNames();
            String         key;

            while (em.hasMoreElements())
            {
               key = (String)em.nextElement();

               if (key.startsWith("dir"))
               {
                  String[] keySplit = key.split("\\.",2);
                  sendLogData(enregJob.submissionID, "Directory : " + propAC.getProperty("dir." + keySplit[1]) + "\n", false);
                  sendLogData(enregJob.submissionID, "Command   : " + propAC.getProperty("cmd." + keySplit[1]) + "\n\n", false);
               }
            }
            sendLogData(enregJob.submissionID, "If required, see " + pgmname + ".AutorizedCommands.properties for correctives mesures.\n", false);

            setJobStatusExecRC(enregJob.submissionID,128);

            // Retrait de la liste d'exécution
            writeLogMessage(Level.WARNING,enregJob.jobName + " (submission ID : " + enregJob.submissionID + ") has completed with a return code of 128 (Not authorized to execute)");
            htJob.remove(enregJob.jobName);
         }
      }

      writeLogMessage(Level.FINE,"Leaving createJobProcess()");
   }


   //************************************************************************
   //*                                                                      *
   //* Méthode :                                                            *
   //*    dailyMaintenance                                                  *
   //*                                                                      *
   //* Description :                                                        *
   //*    Maintenance jounalière associée à l'exécution des tâches.         *
   //*                                                                      *
   //************************************************************************
   private void dailyMaintenance()
   {
      writeLogMessage(Level.FINE,"Entering dailyMaintenance()");

      File              fpLogFile               = null;

      CallableStatement sqlStmtLogFileList      = null;
      ResultSet         sqlResultsetLogFileList = null;


      try
      {
         // Préparation des appels (obtenir la liste / enregistrement des statuts)
         sqlStmtLogFileList = repositoryConnection.prepareCall("{call " + pSDBMSchema + ".SDBM_AGENT.TRAITEMENT_EPURATION_AGT(?,?)}");

         // Enregistrement des paramètres
         sqlStmtLogFileList.setString("A_NOM_SERVEUR",pSDBMHostName);
         sqlStmtLogFileList.registerOutParameter("A_CUR_INFO", OracleTypes.CURSOR);

         // Exécution
         sqlStmtLogFileList.execute();

         // Réception de la liste des cibles à traiter
         sqlResultsetLogFileList = (ResultSet)sqlStmtLogFileList.getObject("A_CUR_INFO");

         // Traitement des fichiers de log
         writeLogMessage(Level.INFO,"dailyMaintenance() : The following files will be deleted...");
         while (sqlResultsetLogFileList.next())
         {
            // Suppression du fichier de log
            fpLogFile = new File(sqlResultsetLogFileList.getString("FICHIER_JOURNAL"));
            if (fpLogFile.exists() && fpLogFile.delete())
               writeLogMessage(Level.INFO,sqlResultsetLogFileList.getString("FICHIER_JOURNAL") + " has been deleted.");
            else
               writeLogMessage(Level.INFO,sqlResultsetLogFileList.getString("FICHIER_JOURNAL") + " was not accessible.");
            fpLogFile = null;
         }

         // Fin de la transaction
         try
         {
            repositoryConnection.commit();
         }
         catch (SQLException ex)
         {
            writeLogMessage(Level.SEVERE,"Error on commit within SDBM repository - dailyMaintenance (" + ex.getMessage().replaceAll("\n"," : NL : ") + ").");
         }

         writeLogMessage(Level.INFO,"dailyMaintenance() : Completed.");
      }
      catch (SQLException ex)
      {
         writeLogMessage(Level.SEVERE,"Unable to get the list of file to delete (" + ex.getMessage().replaceAll("\n"," : NL : ") + ").");
      }
      finally
      {
         //
         // Libération des ressources (niveau référentiel)
         //
         try
         {
            if (sqlResultsetLogFileList != null)
               sqlResultsetLogFileList.close();
            sqlResultsetLogFileList = null;

            if (sqlStmtLogFileList != null)
               sqlStmtLogFileList.close();
            sqlStmtLogFileList = null;

            repositoryConnection.rollback();
         }
         catch (Exception ex)
         {
            writeLogMessage(Level.WARNING,"Error while releasing repository resources for dailyMaintenance.");
         }
      }

      writeLogMessage(Level.FINE,"Leaving dailyMaintenance()");
   }


   //************************************************************************
   //*                                                                      *
   //* Méthode :                                                            *
   //*    executeJob                                                        *
   //*                                                                      *
   //* Description :                                                        *
   //*    Traitement d'exécution des tâches.                                *
   //*                                                                      *
   //************************************************************************
   private void executeJob()
   {
      writeLogMessage(Level.FINE,"Entering executeJob()");

      EnregJob              enregJob;
      Enumeration<EnregJob> enumJob;
      int                   processExitValue;


      enumJob = htJob.elements();
      while (enumJob.hasMoreElements())
      {
         enregJob = enumJob.nextElement();

         if (enregJob.process == null)
         {
            // Création du processus
            createJobProcess(enregJob);
         }
         else
         {
            // Traitement de la tâche en cours d'exécution
            try
            {
               processExitValue = enregJob.process.exitValue();

               // Gestion du fichier de journal - final
               monitorLogFile(enregJob,true);

               setJobStatusExecRC(enregJob.submissionID,processExitValue);

              // Retrait de la liste d'exécution
               writeLogMessage(Level.INFO,enregJob.jobName + " (submission ID : " + enregJob.submissionID + ") has completed with a return code of " + enregJob.process.exitValue());
               htJob.remove(enregJob.jobName);
            }
            catch (IllegalThreadStateException ex)
            {
               writeLogMessage(Level.FINE,enregJob.jobName + " (submission ID : " + enregJob.submissionID + ") is not completed yet.");

               // Gestion du fichier de journal
               monitorLogFile(enregJob,false);
            }
         }
      }

      writeLogMessage(Level.FINE,"Leaving executeJob()");
   }


   //************************************************************************
   //*                                                                      *
   //* Méthode :                                                            *
   //*    loadJobFromRepository                                             *
   //*                                                                      *
   //* Description :                                                        *
   //*    Traitement de chargement des tâches dans la liste local.          *
   //*                                                                      *
   //************************************************************************
   private void loadJobFromRepository()
   {
      writeLogMessage(Level.FINE,"Entering loadJobFromRepository()");

      CallableStatement sqlStmtJobList      = null;
      ResultSet         sqlResultsetJobList = null;

      EnregJob          enregJob;


      try
      {
         // Préparation des appels (obtenir la liste / enregistrement des statuts)
         sqlStmtJobList = repositoryConnection.prepareCall("{call " + pSDBMSchema + ".SDBM_AGENT.TRAITEMENT_TACHES_AGT(?,?,?)}");

         // Enregistrement des paramètres
         sqlStmtJobList.setString("A_NOM_SERVEUR",pSDBMHostName);
         sqlStmtJobList.registerOutParameter("A_FREQU_VERIF_AGENT_TACHE", OracleTypes.INTEGER);
         sqlStmtJobList.registerOutParameter("A_CUR_INFO", OracleTypes.CURSOR);

         // Exécution
         sqlStmtJobList.execute();

         // Réception du délai de vérification
         setSleepTimeJob(sqlStmtJobList.getInt("A_FREQU_VERIF_AGENT_TACHE"));

         // Réception de la liste des cibles à traiter
         sqlResultsetJobList = (ResultSet)sqlStmtJobList.getObject("A_CUR_INFO");

         // Chargement du HashTable
         while (sqlResultsetJobList.next())
         {
            //
            // Traitement
            //

            // Chargement de la cible dans la table
            enregJob = new EnregJob();

            enregJob.submissionID    = sqlResultsetJobList.getLong("ID_SOUMISSION");
            enregJob.jobName         = sqlResultsetJobList.getString("NOM_TACHE");
            enregJob.executableName  = sqlResultsetJobList.getString("EXECUTABLE");
            enregJob.parameters      = sqlResultsetJobList.getString("PARAMETRE");
            enregJob.directoryName   = sqlResultsetJobList.getString("REPERTOIRE");
            enregJob.logFileName     = sqlResultsetJobList.getString("FICHIER_JOURNAL") + "." + sqlResultsetJobList.getLong("ID_SOUMISSION");
            enregJob.logFilePosition = 0;
            enregJob.process         = null;

            // Mise à jour du statut d'exécution (SR : Soumission reçu par l'agent)
            if (!setJobStatusExec(enregJob.submissionID,"SR"))
            {
               writeLogMessage(Level.SEVERE,enregJob.jobName + " (submission ID : " + enregJob.submissionID + ") has not been added from the list of job to execute.");
            }
            else
            {
               htJob.put(sqlResultsetJobList.getString("NOM_TACHE"),enregJob);
               writeLogMessage(Level.INFO,enregJob.jobName + " (submission ID : " + enregJob.submissionID + ") has been added to the list of job to execute.");
            }
         }
      }
      catch (SQLException ex)
      {
         writeLogMessage(Level.SEVERE,"Unable to get the list of job to execute (" + ex.getMessage().replaceAll("\n"," : NL : ") + ").");
      }
      finally
      {
         //
         // Libération des ressources (niveau référentiel)
         //
         try
         {
            if (sqlResultsetJobList != null)
               sqlResultsetJobList.close();
            sqlResultsetJobList = null;

            if (sqlStmtJobList != null)
               sqlStmtJobList.close();
            sqlStmtJobList = null;
         }
         catch (Exception ex)
         {
            writeLogMessage(Level.WARNING,"Error while releasing repository resources for executeJob.");
         }
      }

      writeLogMessage(Level.FINE,"Leaving loadJobFromRepository()");
   }


   //************************************************************************
   //*                                                                      *
   //* Méthode :             t                                              *
   //*    monitorAlertFile                                                  *
   //*                                                                      *
   //* Description :                                                        *
   //*    Traitement de monitoring d'un fichier d'alerte.                   *
   //*                                                                      *
   //************************************************************************
   private void monitorAlertFile(EnregAlert enregAlert)
   {
      // Statistique fichier
      File fpAlert = null;
      long fileCurrentSize;

      // Lecture du fichier
      RandomAccessFile   fileAlert   = null;
      LinkedList<String> listMessage = null;
      String message                 = null;

      // Mise à jour du statut dans le référentiel SDBM
      CallableStatement sqlStmtEventStatus = null;


      // Recherche de la grosseur actuel du fichier
      fpAlert = new File(enregAlert.fileName);
      if (fpAlert.exists())
      {
         fileCurrentSize = fpAlert.length();

         // Si c'est un nouveau fichier (on ne traite pas ce cycle)
         if (enregAlert.filePosition < 0)
         {
            // Mise à jour du pointeur de fin de fichier
            enregAlert.filePosition = fileCurrentSize;
            writeLogMessage(Level.INFO,"Initial offset for file " + enregAlert.fileName + " is " + enregAlert.filePosition + ".");
         }
         else if (enregAlert.filePosition != fileCurrentSize)
         {
            // Vérification de réinitialisation du fichier
            if (enregAlert.filePosition > fileCurrentSize)
            {
               enregAlert.filePosition = 0;
               writeLogMessage(Level.INFO,"Reset of offset for file " + enregAlert.fileName + ".");
            }

            // Le fichier à été modifié, le traitement est requis
            writeLogMessage(Level.FINE,"Reading of file " + enregAlert.fileName + " will start at offset " + enregAlert.filePosition + " (current size is " + fileCurrentSize + ").");

            try
            {
               listMessage = new LinkedList<String>();

               fileAlert = new RandomAccessFile(fpAlert,"r");
               fileAlert.seek(enregAlert.filePosition);

               while (fileAlert.getFilePointer() < fileCurrentSize)
               {
                  message = fileAlert.readLine().replaceAll("\0","");
                  if (message.length() > 0)
                  {
                     listMessage.addLast(message);
                  }
               }

               // Sauvegarde de la nouvelle fin de fichier
               enregAlert.filePosition = fileCurrentSize;
               writeLogMessage(Level.FINE,"Reading of file " + enregAlert.fileName + " end at offset " + enregAlert.filePosition + ".");

               // Fermeture du fichier
               fileAlert.close();
               fileAlert = null;


               // Traitement du contenu de la liste
               ListIterator<String> iteratorListMessage = listMessage.listIterator();
               boolean              endOfMessageFound;
               boolean              startOfMessageFound;
               String               msgBuffer = null;

               while (iteratorListMessage.hasNext())
               {
                  message = iteratorListMessage.next();
                  writeLogMessage(Level.FINE,"Line is       : " + message);

                  if (
                           (enregAlert.targetSubType.contentEquals("OR") && (message.startsWith("ORA-") || message.startsWith("WARNING:") || message.startsWith("ERROR:") || message.startsWith("Corrupt ")))
                        || (enregAlert.targetSubType.contentEquals("MS") && (message.contains("Error") && !message.contains("Error: 18456")))
                        || (enregAlert.targetSubType.contentEquals("MY") && (message.contains("[ERROR]") || message.startsWith("ERROR:")))
                                                                                                                                             )
                  {
                     if (enregAlert.targetSubType.contentEquals("OR"))
                     {
                        //
                        // Nous avons un message Oracle
                        //

                        if ((message.startsWith("ORA-01555")) && (!message.startsWith("ORA-01555:")))
                        {
                           try
                           {
                              //
                              // Gestion particulière des ORA-01555 (message avec SQL)
                              //

                              // Changement de direction (itérateur)
                              iteratorListMessage.previous();

                              // Date / heure du ORA-01555 (si existant)
                              if (iteratorListMessage.hasPrevious())
                              {
                                 msgBuffer = iteratorListMessage.previous() + "\n";

                                 // Changement de direction (itérateur)
                                 iteratorListMessage.next();

                                  // ORA-01555 (message)
                                 msgBuffer = msgBuffer + iteratorListMessage.next() + "\n";

                                 // Date / heure du SQL
                                 msgBuffer = msgBuffer + iteratorListMessage.next() + "\n";

                                 // Recherche de la fin du message (date du message suivant)
                                 endOfMessageFound = false;
                                 while (iteratorListMessage.hasNext() && !endOfMessageFound)
                                 {
                                    message = iteratorListMessage.next();

                                    if (oraDatePattern.matcher(message).matches())
                                       endOfMessageFound = true;
                                    else
                                       msgBuffer = msgBuffer + message + "\n";
                                 }

                                 // Si ce n'est pas le dernier message, on se repositionne
                                 if (iteratorListMessage.hasNext())
                                    iteratorListMessage.previous();
                              }
                              else
                              {
                                 // ORA-01555 (message)
                                 msgBuffer = iteratorListMessage.next() + "\n";

                                 // Le message est mal formaté...  On n'essaye plus de comprendre...
                                 if (msgBuffer != null)
                                    msgBuffer = msgBuffer + "\n" + "*** Warning : Unable to find the date while processing ORA-01555 ***" + "\n";
                                 else
                                    msgBuffer = "*** Warning : Unable to find the date while processing ORA-01555 ***" + "\n";

                                 writeLogMessage(Level.WARNING,"Unable to find the date while processing ORA-01555 for event ALERT, target " + enregAlert.targetName + ".");
                              }
                           }
                           catch (NoSuchElementException ex)
                           {
                              if (msgBuffer != null)
                                 msgBuffer = msgBuffer + "\n" + "*** Warning : Processing of ORA-01555 failed ***" + "\n";
                              else
                                 msgBuffer = "*** Warning : Processing of ORA-01555 failed ***" + "\n";

                              writeLogMessage(Level.WARNING,"Processing of ORA-01555 failed for event ALERT, target " + enregAlert.targetName + ".");
                           }
                        }
                        else
                        {
                           //
                           // Gestion ORA-, WARNING:, ERROR:, Corrupt (Corrupt block ou Corrupt Block)
                           //

                           // Recherche du début de l'erreur (format date)
                           startOfMessageFound = false;
                           while (iteratorListMessage.hasPrevious() && !startOfMessageFound)
                           {
                              message = iteratorListMessage.previous();

                              if (oraDatePattern.matcher(message).matches())
                                 startOfMessageFound = true;
                           }

                           // Date / heure du message
                           msgBuffer = message + "\n";

                           // Changement de direction (itérateur)
                           iteratorListMessage.next();

                           // Recherche de la fin du message (date du message suivant)
                           endOfMessageFound = false;
                           while (iteratorListMessage.hasNext() && !endOfMessageFound)
                           {
                              message = iteratorListMessage.next();

                              if (oraDatePattern.matcher(message).matches())
                                 endOfMessageFound = true;
                              else
                                 msgBuffer = msgBuffer + message + "\n";
                           }

                           // Si ce n'est pas le dernier message, on se repositionne
                           if (iteratorListMessage.hasNext())
                              iteratorListMessage.previous();
                        }
                        writeLogMessage(Level.FINE,"*** msgBuffer is ***\n***\n" + msgBuffer + "***");
                     }
                     else
                     {
                        //
                        // Nous avons un message SQLServer ou MySQL
                        //
                        msgBuffer = message;
                        writeLogMessage(Level.FINE,"*** msgBuffer is ***\n***\n" + msgBuffer + "***");
                     }


                     //
                     // Sauvegarde du message dans le référentiel SDBM
                     //

                     try
                     {
                        // Préparation de l'appel Oracle
                        if (sqlStmtEventStatus == null)
                           sqlStmtEventStatus = repositoryConnection.prepareCall("{call " + pSDBMSchema + ".SDBM_AGENT.SAUVEGARDE_STATUT_EVEN_AGT_BD(?,?,?)}");

                        // Enregistrement du statut de l'événement - Préparation des paramètres
                        sqlStmtEventStatus.setString("A_NOM_CIBLE",enregAlert.targetName);
                        sqlStmtEventStatus.setString("A_NOM_EVENEMENT","ALERT");

                        // Vérification de la longueur du tempon (max. 4000)
                        if (msgBuffer.length() > 3996)
                           msgBuffer = msgBuffer.substring(0,3996) + " ...";

                        sqlStmtEventStatus.setString("A_TEXTE",msgBuffer);

                        // Exécution
                        sqlStmtEventStatus.execute();
                     }
                     catch (SQLException ex)
                     {
                        writeLogMessage(Level.SEVERE,"Unable to send the event status to SDBM repository for event ALERT, target " + enregAlert.targetName + " (" + ex.getMessage().replaceAll("\n"," : NL : ") + ").");
                     }

                  }

               } // Fin du while

               // Libération de la liste
               iteratorListMessage = null;
               listMessage.clear();
               listMessage = null;

               //
               // Libération des ressources (niveau référentiel)
               //
               try
               {
                  if (sqlStmtEventStatus != null)
                     sqlStmtEventStatus.close();

                  sqlStmtEventStatus = null;

               }
               catch (Exception ex)
               {
                  writeLogMessage(Level.WARNING,"Error while releasing repository resources for monitorAlertFile.");
               }

            }
            catch (IOException ex)
            {
               writeLogMessage(Level.WARNING,"Unable to read the file " + enregAlert.fileName + " for target " + enregAlert.targetName + " (" + ex.getMessage() + ").");
            }
         }
      }
      else
      {
         writeLogMessage(Level.WARNING,"Unable to get the size of the file " + enregAlert.fileName + " for target " + enregAlert.targetName + " (file does not exists).");
      }
   }


   //************************************************************************
   //*                                                                      *
   //* Méthode :                                                            *
   //*    monitorAlert                                                      *
   //*                                                                      *
   //* Description :                                                        *
   //*    Traitement de monitoring pricipal (fichiers d'alertes).           *
   //*                                                                      *
   //************************************************************************
   private void monitorAlert()
   {
      writeLogMessage(Level.FINE,"Entering monitorAlert()");

      //
      //
      // Traitement des cibles
      //
      //
      CallableStatement       sqlStmtTargetList          = null;
      CallableStatement       sqlStmtEventReturnHandling = null;
      ResultSet               sqlResultsetTargetList     = null;

      EnregAlert              enregAlert;
      Enumeration<EnregAlert> enumAlert;

      try
      {
         // Préparation des appels (obtenir la liste / enregistrement des statuts)
         sqlStmtTargetList          = repositoryConnection.prepareCall("{call " + pSDBMSchema + ".SDBM_AGENT.TRAITEMENT_EVENEMENTS_AGT_BD(?,?,?,?,?)}");
         sqlStmtEventReturnHandling = repositoryConnection.prepareCall("{call " + pSDBMSchema + ".SDBM_AGENT.TRAITER_STATUT_EVEN_AGT_BD(?)}");

         // Enregistrement des paramètres
         sqlStmtTargetList.setString("A_VERSION_AGENT",version);
         sqlStmtTargetList.setString("A_NOM_SERVEUR",pSDBMHostName);
         sqlStmtTargetList.setString("A_NOM_EVENEMENT","ALERT");
         sqlStmtTargetList.registerOutParameter("A_FREQU_VERIF_AGENT", OracleTypes.INTEGER);
         sqlStmtTargetList.registerOutParameter("A_CUR_INFO", OracleTypes.CURSOR);

         // Exécution
         sqlStmtTargetList.execute();

         // Réception du délai de vérification
         setSleepTime(sqlStmtTargetList.getInt("A_FREQU_VERIF_AGENT"));

         // Réception de la liste des cibles à traiter
         sqlResultsetTargetList = (ResultSet)sqlStmtTargetList.getObject("A_CUR_INFO");

         //
         // Préparation du hashTable
         //
         enumAlert = htAlert.elements();

         // Remise à zéro
         writeLogMessage(Level.FINE,"Reset of isStillActive flags (all target(s)).");
         while (enumAlert.hasMoreElements())
         {
            enregAlert = enumAlert.nextElement();
            enregAlert.isStillActive = false;
         }

         // Chargement du HashTable
         while (sqlResultsetTargetList.next())
         {
            //
            // Traitement
            //

            // Chargement de la cible dans la table
            if (htAlert.containsKey(sqlResultsetTargetList.getString("NOM_CIBLE")))
            {
               enregAlert = htAlert.get(sqlResultsetTargetList.getString("NOM_CIBLE"));

               enregAlert.targetSubType = sqlResultsetTargetList.getString("SOUS_TYPE_CIBLE");
               enregAlert.fileName      = sqlResultsetTargetList.getString("FICHIER_ALERTE");
               enregAlert.isStillActive = true;

               writeLogMessage(Level.FINE,"Target " + enregAlert.targetName + " is now active.");
            }
            else
            {
               enregAlert = new EnregAlert();

               enregAlert.targetName    = sqlResultsetTargetList.getString("NOM_CIBLE");
               enregAlert.targetSubType = sqlResultsetTargetList.getString("SOUS_TYPE_CIBLE");
               enregAlert.fileName      = sqlResultsetTargetList.getString("FICHIER_ALERTE");
               enregAlert.filePosition  = -1;
               enregAlert.isStillActive = true;

               htAlert.put(sqlResultsetTargetList.getString("NOM_CIBLE"),enregAlert);

               writeLogMessage(Level.INFO,enregAlert.targetName + " has been added to the list of monitored targets.");
            }
         }

         // Traitement des fichiers
         enumAlert = htAlert.elements();
         while (enumAlert.hasMoreElements())
         {
            enregAlert = enumAlert.nextElement();

            if (enregAlert.isStillActive != false)
            {
               writeLogMessage(Level.FINE,"Call to monitorAlert() for " + enregAlert.targetName + ".");
               monitorAlertFile(enregAlert);
               writeLogMessage(Level.FINE,"Return from monitorAlert() for " + enregAlert.targetName + ".");
            }
            else
            {

               htAlert.remove(enregAlert.targetName);
               writeLogMessage(Level.INFO,enregAlert.targetName + " has been removed from the list of monitored targets.");
            }
         }

         try
         {
            // Enregistrement du statut de l'événement - Préparation des paramètres
            sqlStmtEventReturnHandling.setString("A_NOM_SERVEUR",pSDBMHostName);

            // Exécution
            sqlStmtEventReturnHandling.execute();
         }
         catch (SQLException ex)
         {
            writeLogMessage(Level.SEVERE,"Error while processing the status change within SDBM repository for server " + pSDBMHostName + " (" + ex.getMessage().replaceAll("\n"," : NL : ") + ").");
         }

         // Fin de la transaction
         try
         {
            repositoryConnection.commit();
         }
         catch (SQLException ex)
         {
            writeLogMessage(Level.SEVERE,"Error on commit within SDBM repository - monitorAlert (" + ex.getMessage().replaceAll("\n"," : NL : ") + ").");
         }
      }
      catch (SQLException ex)
      {
         writeLogMessage(Level.SEVERE,"Unable to get the target list (" + ex.getMessage().replaceAll("\n"," : NL : ") + ").");
      }
      finally
      {
         //
         // Libération des ressources (niveau référentiel)
         //
         try
         {
            if (sqlResultsetTargetList != null)
               sqlResultsetTargetList.close();
            sqlResultsetTargetList = null;

            if (sqlStmtEventReturnHandling != null)
               sqlStmtEventReturnHandling.close();
            sqlStmtEventReturnHandling = null;

            if (sqlStmtTargetList != null)
               sqlStmtTargetList.close();
            sqlStmtTargetList = null;
         }
         catch (Exception ex)
         {
            writeLogMessage(Level.WARNING,"Error while releasing repository resources for monitor.");
         }
      }

      writeLogMessage(Level.FINE,"Leaving monitorAlert()");
   }


   //************************************************************************
   //*                                                                      *
   //* Méthode :                                                            *
   //*    registerAgent                                                     *
   //*                                                                      *
   //* Description :                                                        *
   //*    Enregistrement de l'agent.                                        *
   //*                                                                      *
   //************************************************************************
   private void registerAgent()
   {
      //
      // Probing system information
      //
      SysInfo   sysinfo = null;
      Uptime    uptime  = null;
      CpuInfo[] cpuinfo = null;
      Mem       meminfo = null;


      if (pSDBMSysStatistics.equalsIgnoreCase("AC"))
      {
         try
         {
            // SysInfo
            sysinfo = new SysInfo();
            sysinfo.gather(sigar);
         }
         catch (SigarException ex)
         {
            writeLogMessage(Level.WARNING,"SIGAR error : call failed to SysInfo().gather() (" + ex.getMessage().replaceAll("\n"," : NL : ") + ").");
         }

         try
         {
            // Uptime
            uptime  = sigar.getUptime();
         }
         catch (SigarException ex)
         {
            writeLogMessage(Level.INFO,"SIGAR error : call failed to getUptime() (" + ex.getMessage().replaceAll("\n"," : NL : ") + ").");
         }

         try
         {
            // CpuInfo
            cpuinfo = sigar.getCpuInfoList();
         }
         catch (SigarException ex)
         {
            writeLogMessage(Level.WARNING,"SIGAR error : call failed to getCpuInfoList() (" + ex.getMessage().replaceAll("\n"," : NL : ") + ").");
         }

         try
         {
            // Mem
            meminfo = sigar.getMem();
         }
         catch (SigarException ex)
         {
            writeLogMessage(Level.WARNING,"SIGAR error : call failed to getMem() (" + ex.getMessage().replaceAll("\n"," : NL : ") + ").");
         }
      }


      //
      // Registering agent into repository
      //
      CallableStatement sqlStmtRegisterAgent = null;

      writeLogMessage(Level.INFO,"Registering agent into repository...");
      try
      {
         // Préparation des appels (obtenir la liste / enregistrement des statuts)
         sqlStmtRegisterAgent = repositoryConnection.prepareCall("{call " + pSDBMSchema + ".SDBM_AGENT.ENREGISTRER_AGT(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)}");

         // Enregistrement des paramètres
         sqlStmtRegisterAgent.setString("A_NOM_SERVEUR",pSDBMHostName);
         sqlStmtRegisterAgent.setString("A_NOM_OS",System.getProperty("os.name") + " - " + System.getProperty("os.arch") + " (" + System.getProperty("os.version") + ")");
         sqlStmtRegisterAgent.setString("A_USAGER_EXECUTION",System.getProperty("user.name"));
         sqlStmtRegisterAgent.setString("A_STATUT_TACHE",pSDBMTaskScheduler.toUpperCase());

         if (uptime != null)
            sqlStmtRegisterAgent.setDouble("A_SYS_UPTIME",uptime.getUptime());
         else
            sqlStmtRegisterAgent.setDouble("A_SYS_UPTIME",-1);

         if (sysinfo != null)
         {
            sqlStmtRegisterAgent.setString("A_SYS_ARCH",sysinfo.getArch());
            sqlStmtRegisterAgent.setString("A_SYS_VENDOR",sysinfo.getVendor());
            sqlStmtRegisterAgent.setString("A_SYS_DESCRIPTION",sysinfo.getDescription());
            sqlStmtRegisterAgent.setString("A_SYS_VENDOR_NAME",sysinfo.getVendorName());
            sqlStmtRegisterAgent.setString("A_SYS_VENDOR_VERSION",sysinfo.getVendorVersion());
            sqlStmtRegisterAgent.setString("A_SYS_VERSION",sysinfo.getVersion());
            sqlStmtRegisterAgent.setString("A_SYS_PATCH_LEVEL",sysinfo.getPatchLevel());
         }
         else
         {
            sqlStmtRegisterAgent.setString("A_SYS_ARCH","");
            sqlStmtRegisterAgent.setString("A_SYS_VENDOR","");
            sqlStmtRegisterAgent.setString("A_SYS_DESCRIPTION","");
            sqlStmtRegisterAgent.setString("A_SYS_VENDOR_NAME","");
            sqlStmtRegisterAgent.setString("A_SYS_VENDOR_VERSION","");
            sqlStmtRegisterAgent.setString("A_SYS_VERSION","");
            sqlStmtRegisterAgent.setString("A_SYS_PATCH_LEVEL","");
         }

         if (cpuinfo != null)
         {
            sqlStmtRegisterAgent.setInt("A_SYS_NB_CORE",cpuinfo[0].getTotalCores());
            sqlStmtRegisterAgent.setString("A_HAR_CPU_VENDOR",cpuinfo[0].getVendor());
            sqlStmtRegisterAgent.setString("A_HAR_CPU_MODEL",cpuinfo[0].getModel());
            sqlStmtRegisterAgent.setInt("A_HAR_CPU_CLOCK_MHZ",cpuinfo[0].getMhz());
         }
         else
         {
            sqlStmtRegisterAgent.setInt("A_SYS_NB_CORE",0);
            sqlStmtRegisterAgent.setString("A_HAR_CPU_VENDOR","");
            sqlStmtRegisterAgent.setString("A_HAR_CPU_MODEL","");
            sqlStmtRegisterAgent.setInt("A_HAR_CPU_CLOCK_MHZ",0);
         }

         if (meminfo != null)
            sqlStmtRegisterAgent.setLong("A_HAR_RAM_SIZE",meminfo.getRam());
         else
            sqlStmtRegisterAgent.setLong("A_HAR_RAM_SIZE",0);


         if (System.getProperty("os.name").startsWith("Windows"))
            sqlStmtRegisterAgent.setString("A_LISTE_INTERPRETEUR","cmd.exe (/u),cmd.exe (/a)");
         else
         {
            File binDir = new File("/bin");

            String listFilename[] = binDir.list();
            String strShell = "";

            for (int i = 0; i < listFilename.length; i++)
            {
               if (listFilename[i].endsWith("sh"))
               {
                  if (!new File("/bin/" + listFilename[i]).isDirectory())
                  {
                     if (strShell.length() == 0)
                        strShell = "/bin/" + listFilename[i];
                     else
                        strShell = strShell + "," + "/bin/" + listFilename[i];
                  }
               }
            }
            sqlStmtRegisterAgent.setString("A_LISTE_INTERPRETEUR",strShell);
         }

         // Exécution
         sqlStmtRegisterAgent.execute();

         // Fin de la transaction
         try
         {
            repositoryConnection.commit();
         }
         catch (SQLException ex)
         {
            writeLogMessage(Level.SEVERE,"Error on commit within SDBM repository - registerAgent (" + ex.getMessage().replaceAll("\n"," : NL : ") + ").");
         }
      }
      catch (SQLException ex)
      {
         writeLogMessage(Level.SEVERE,"Unable to register the agent (" + ex.getMessage().replaceAll("\n"," : NL : ") + ").");
      }
      finally
      {
         //
         // Libération des ressources (niveau référentiel)
         //
         try
         {
            if (sqlStmtRegisterAgent != null)
               sqlStmtRegisterAgent.close();
            sqlStmtRegisterAgent = null;
         }
         catch (Exception ex)
         {
            writeLogMessage(Level.WARNING,"Error while releasing repository resources for registerAgent.");
         }

      }

      writeLogMessage(Level.INFO,"Registering agent completed.");
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
         Properties prop                  = loadParams(pgmname);
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

         pSDBMLogLevel = prop.getProperty("SDBMLogLevel");
         if (pSDBMLogLevel == null)
         {
            pSDBMLogLevel = "";
         }

         pSDBMHostName = prop.getProperty("SDBMHostName");
         if (pSDBMHostName == null)
         {
            pSDBMHostName = "";
         }

         pSDBMTaskScheduler = prop.getProperty("SDBMTaskScheduler");
         if (pSDBMTaskScheduler == null)
         {
            pSDBMTaskScheduler = "";
         }

         pSDBMTaskSchedulerAllowBackQuotes = prop.getProperty("SDBMTaskSchedulerAllowBackQuotes");
         if (pSDBMTaskSchedulerAllowBackQuotes == null)
         {
            pSDBMTaskSchedulerAllowBackQuotes = "";
         }

         pSDBMSysStatistics = prop.getProperty("SDBMSysStatistics");
         if (pSDBMSysStatistics == null)
         {
            pSDBMSysStatistics = "";
         }

         pSDBMCPUStatistics = prop.getProperty("SDBMCPUStatistics");
         if (pSDBMCPUStatistics == null)
         {
            pSDBMCPUStatistics = "";
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

         // SDBMLogLevel
         writeLogMessage(Level.INFO,"SDBMLogLevel   : " + pSDBMLogLevel);

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

         if (pSDBMLogLevel.contentEquals(""))
         {
            writeLogMessage(Level.WARNING,"SDBMLogLevel is not set.");
         }

         if (pSDBMHostName.contentEquals(""))
         {
            try
            {
               pSDBMHostName = InetAddress.getLocalHost().getHostName();
            }
            catch (Exception ex)
            {
               writeLogMessage(Level.SEVERE,"SDBMHostName was not set and getHostName() call has failed.");
               System.exit(1);
            }
            writeLogMessage(Level.INFO,"SDBMHostName was not set (" + pSDBMHostName + " will be used as hostname).");
         }

         if (pSDBMTaskScheduler.contentEquals(""))
         {
            writeLogMessage(Level.WARNING,"SDBMTaskScheduler is not set. The task scheduler has been enabled.");
            pSDBMTaskScheduler = "AC";
         }
         else if (pSDBMTaskScheduler.equalsIgnoreCase("AC"))
         {
            writeLogMessage(Level.INFO,"The task scheduler has been enabled.");
         }
         else if (pSDBMTaskScheduler.equalsIgnoreCase("IN"))
         {
            writeLogMessage(Level.INFO,"The task scheduler has been disabled.");
         }
         else
         {
            writeLogMessage(Level.WARNING,"SDBMTaskScheduler is not set to a valid value (AC or IN). The task scheduler has been enabled.");
            pSDBMTaskScheduler = "AC";
         }

         if (pSDBMTaskScheduler.equalsIgnoreCase("AC"))
         {
            if (pSDBMTaskSchedulerAllowBackQuotes.contentEquals(""))
            {
               writeLogMessage(Level.WARNING,"SDBMTaskSchedulerAllowBackQuotes is not set. The back-quotes will not be allowed as tasks parameters (task scheduler).");
               pSDBMTaskSchedulerAllowBackQuotes = "IN";
            }
            else if (pSDBMTaskSchedulerAllowBackQuotes.equalsIgnoreCase("AC"))
            {
               writeLogMessage(Level.INFO,"The back-quotes will be allowed as tasks parameters (task scheduler). This could allow the bypass of the security provided by arguments validation.");
            }
            else if (pSDBMTaskSchedulerAllowBackQuotes.equalsIgnoreCase("IN"))
            {
               writeLogMessage(Level.INFO,"The back-quotes will not be allowed as tasks parameters (task scheduler).");
            }
            else
            {
               writeLogMessage(Level.WARNING,"SDBMTaskScheduler is not set to a valid value (AC or IN). The back-quotes will not be allowed as tasks parameters (task scheduler).");
               pSDBMTaskSchedulerAllowBackQuotes = "IN";
            }

            //
            // Chargement du fichier de paramètre
            //
            writeLogMessage(Level.INFO,"Reading properties files (AuthorizedCommands)...");
            loadAuthorizedCommands();
            writeLogMessage(Level.INFO,"Reading properties files (AuthorizedCommands) completed.");

            if (propAC.isEmpty())
            {
               writeLogMessage(Level.WARNING,"No authorized commands has been declared. Any commands scheduled will be executed without arguments validation. This could pose a security threat.");
            }
            else
            {
               // Affichage de la liste (journal de la tâche)
               Enumeration<?> em = propAC.propertyNames();
               String         key;
               StringBuffer   stringBuffer = new StringBuffer();

               while (em.hasMoreElements())
               {
                  key = (String)em.nextElement();

                  if (key.startsWith("dir"))
                  {
                     String[] keySplit = key.split("\\.",2);
                     stringBuffer.append("Directory: |" + propAC.getProperty("dir." + keySplit[1]) + "|, " + "Command: |" + propAC.getProperty("cmd." + keySplit[1]) + "|; ");
                  }
               }

               writeLogMessage(Level.INFO,"Authorized commands from " + pgmname + ".AuthorizedCommands.properties are : " + stringBuffer.toString());
               stringBuffer = null;
            }
         }

         if (pSDBMSysStatistics.contentEquals(""))
         {
            writeLogMessage(Level.WARNING,"SDBMSysStatistics is not set. The system statistics will be collected.");
            pSDBMSysStatistics = "AC";
         }
         else if (pSDBMSysStatistics.equalsIgnoreCase("AC"))
         {
            writeLogMessage(Level.INFO,"The system statistics will be collected.");
         }
         else if (pSDBMSysStatistics.equalsIgnoreCase("IN"))
         {
            writeLogMessage(Level.INFO,"The system statistics will not be collected.");

            // Dépendance sur les statistiques systèmes
            pSDBMCPUStatistics = "IN";
         }
         else
         {
            writeLogMessage(Level.WARNING,"SDBMSysStatistics is not set to a valid value (AC or IN). The system statistics will be collected");
            pSDBMSysStatistics = "AC";
         }

         if (pSDBMCPUStatistics.contentEquals(""))
         {
            writeLogMessage(Level.INFO,"The CPU statistics will be collected (SDBMCPUStatistics not set).");
            pSDBMCPUStatistics = "AC";
         }
         else if (pSDBMCPUStatistics.equalsIgnoreCase("AC"))
         {
            writeLogMessage(Level.INFO,"The CPU statistics will be collected.");
         }
         else if (pSDBMCPUStatistics.equalsIgnoreCase("IN"))
         {
            writeLogMessage(Level.INFO,"The CPU statistics will not be collected.");
         }
         else
         {
            writeLogMessage(Level.WARNING,"SDBMCPUStatistics is not set to a valid value (AC or IN). The CPU statistics will be collected");
            pSDBMCPUStatistics = "AC";
         }

         writeLogMessage(Level.INFO,"Checking initialisation parameters completed.");


         // Ajustement du niveau de journalisation
         setLogMessageLevel(pSDBMLogLevel);

         // Traitement principal
         writeLogMessage(Level.INFO,"Registering JDBC drivers...");
         DriverManager.registerDriver(new oracle.jdbc.driver.OracleDriver());
         writeLogMessage(Level.INFO,"oracle.jdbc.driver.OracleDriver() has been registered.");
         writeLogMessage(Level.INFO,"Registering JDBC drivers completed.");

         int  intGarbageCollection              = 0;
         long systemTime                        = 0;
         long lastTimeExecMonitorAlert          = 0;
         long lastTimeExecLoadJobFromRepository = 0;

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


            // Exécution des tâches - quotidienne
            calendar.setTime(new Date());
            if (dayOfLastDailyMaintenance != calendar.get(Calendar.DAY_OF_MONTH))
            {
               // Mise à jour de l'information agent - statique
               connectToRepository();
               registerAgent();

               if (pSDBMTaskScheduler.equalsIgnoreCase("AC"))
                  dailyMaintenance();

               dayOfLastDailyMaintenance = calendar.get(Calendar.DAY_OF_MONTH);
            }

            // Traitement des alertes
            systemTime = System.currentTimeMillis() / 1000;
            if ((lastTimeExecMonitorAlert + pSDBMSleepTime) < systemTime)
            {
               connectToRepository();
               monitorAlert();
               lastTimeExecMonitorAlert = systemTime;
            }

            // Traitement des tâches
            if (pSDBMTaskScheduler.equalsIgnoreCase("AC"))
            {
               systemTime = System.currentTimeMillis() / 1000;
               if ((lastTimeExecLoadJobFromRepository + pSDBMSleepTimeJob) < systemTime)
               {
                  connectToRepository();
                  loadJobFromRepository();
                  lastTimeExecLoadJobFromRepository = systemTime;
               }

               // Exécution des taches
               executeJob();
            }


            if (pSDBMSysStatistics.equalsIgnoreCase("AC"))
            {
               // Traitement des statistiques dynamiques
               calendar.setTime(new Date());
               if (minOfLastSysStatistics != calendar.get(Calendar.MINUTE))
               {
                  // Retrait de la précision pour sauvegarde jusqu'au minute
                  calendar.set(Calendar.SECOND, 0);
                  calendar.set(Calendar.MILLISECOND, 0);

                  connectToRepository();
                  collectSystemStatistics();

                  minOfLastSysStatistics = calendar.get(Calendar.MINUTE);
               }
            }

            // Delai d'attente interne
            wait(sleepInternal);
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
         writeLogMessage(Level.SEVERE,ex.toString());
         ex.printStackTrace();
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

      IApp app = new SDBMAgt();
      ShutdownInterceptor shutdownInterceptor = new ShutdownInterceptor(app);
      Runtime.getRuntime().addShutdownHook(shutdownInterceptor);
      app.start();
   }

}
